import 'dart:async';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as image;
import 'package:thermal_printer_flutter/thermal_printer_flutter.dart';

/// Sends ESC/POS jobs to a paired Bluetooth thermal printer.
class ThermalReceiptPrinter {
  ThermalReceiptPrinter._();

  // Shared 80 mm ESC/POS receipt appearance used by every thermal print.
  static const paperSize = PaperSize.mm80;
  static const normalStyle = PosStyles.defaults(fontType: PosFontType.fontA);
  static const boldStyle = PosStyles.defaults(
    fontType: PosFontType.fontA,
    bold: true,
  );
  static const centerStyle = PosStyles.defaults(
    fontType: PosFontType.fontA,
    align: PosAlign.center,
  );
  static const centerBoldStyle = PosStyles.defaults(
    fontType: PosFontType.fontA,
    align: PosAlign.center,
    bold: true,
  );
  static const rightStyle = PosStyles.defaults(
    fontType: PosFontType.fontA,
    align: PosAlign.right,
  );
  static const rightBoldStyle = PosStyles.defaults(
    fontType: PosFontType.fontA,
    align: PosAlign.right,
    bold: true,
  );

  static final _printer = ThermalPrinterFlutter();
  static const _usbChannel = MethodChannel('inventory/usb_thermal_printer');
  static Printer? _selectedBluetoothPrinter;
  static String? _savedBluetoothAddress;

  /// Renders Tamil and Marathi as a bitmap before printing. ESC/POS built-in
  /// fonts are limited to Latin code pages, while bitmap printing works on
  /// standard thermal printers regardless of their configured code page.
  static Future<List<int>> receiptText(
    Generator generator,
    String text, {
    PosStyles styles = normalStyle,
  }) async {
    if (!RegExp(r'[\u0900-\u097F\u0B80-\u0BFF]').hasMatch(text)) {
      return generator.text(text, styles: styles);
    }
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(color: Colors.black, fontSize: 24),
      ),
      textDirection: TextDirection.ltr,
      textAlign: switch (styles.align) {
        PosAlign.center => TextAlign.center,
        PosAlign.right => TextAlign.right,
        _ => TextAlign.left,
      },
    )..layout(maxWidth: 540);
    final width = 576;
    final height = painter.height.ceil() + 12;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..drawColor(Colors.white, BlendMode.src)
      ..translate(18, 6);
    painter.paint(canvas, Offset.zero);
    final rendered = await recorder.endRecording().toImage(width, height);
    final data = await rendered.toByteData(format: ui.ImageByteFormat.png);
    rendered.dispose();
    if (data == null) return generator.text(text, styles: styles);
    final bitmap = image.decodePng(data.buffer.asUint8List());
    if (bitmap == null) return generator.text(text, styles: styles);
    return generator.image(bitmap, align: styles.align);
  }

  /// Produces a single receipt line with a script-aware product name at the
  /// left and quantity/price/total aligned at the right.
  static Future<List<int>> receiptItemRow(
    Generator generator, {
    required String name,
    required String amount,
  }) async {
    // Receipt rows have a fixed printable width. Keep names on one line and
    // make the truncation predictable for every selected language.
    final displayName = name.length > 13 ? '${name.substring(0, 13)}..' : name;
    if (!RegExp(r'[\u0900-\u097F\u0B80-\u0BFF]').hasMatch(displayName)) {
      return generator.row([
        PosColumn(text: displayName, width: 4, styles: normalStyle),
        PosColumn(text: amount, width: 8, styles: rightStyle),
      ]);
    }
    final namePainter = TextPainter(
      text: TextSpan(
        text: displayName,
        style: const TextStyle(color: Colors.black, fontSize: 23),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: 280);
    final amountPainter = TextPainter(
      text: TextSpan(
        text: amount,
        style: const TextStyle(color: Colors.black, fontSize: 20),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.right,
    )..layout(maxWidth: 265);
    final height = [namePainter.height, amountPainter.height]
            .reduce((a, b) => a > b ? a : b)
            .ceil() +
        12;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..drawColor(Colors.white, BlendMode.src);
    namePainter.paint(canvas, const Offset(12, 6));
    amountPainter.paint(canvas, Offset(564 - amountPainter.width, 7));
    final rendered = await recorder.endRecording().toImage(576, height);
    final data = await rendered.toByteData(format: ui.ImageByteFormat.png);
    rendered.dispose();
    if (data == null) return generator.text('$displayName  $amount', styles: normalStyle);
    final bitmap = image.decodePng(data.buffer.asUint8List());
    if (bitmap == null) return generator.text('$displayName  $amount', styles: normalStyle);
    return generator.image(bitmap, align: PosAlign.left);
  }

  /// Clears the printer selected for this app session.
  static void resetPrinter() {
    _selectedBluetoothPrinter = null;
    _savedBluetoothAddress = null;
    unawaited(_clearSavedBluetoothAddress());
  }

  /// Lets the user select one of the phone's paired printers, then prints.
  static Future<void> print(BuildContext context, List<int> bytes) async {
    try {
      final usbPrinters = await _usbPrinters();
      if (!context.mounted) return;
      if (usbPrinters.isNotEmpty) {
        final selected = await _chooseUsbPrinter(context, usbPrinters);
        if (selected == null || !context.mounted) return;
        _show(context, 'Sending receipt to ${selected['name']} by USB…');
        await _usbChannel.invokeMethod('print', {
          'id': selected['id'],
          'bytes': Uint8List.fromList(bytes),
        });
        if (context.mounted) _show(context, 'Receipt sent to ${selected['name']} by USB.');
        return;
      }
      final permitted = await _printer.checkBluetoothPermissions();
      if (!context.mounted) return;
      if (!permitted) {
        _show(context, 'Bluetooth permission was not granted. Allow Nearby devices, then try again.');
        return;
      }
      if (!await _printer.isBluetoothEnabled()) {
        if (!context.mounted) return;
        final enabled = await _printer.enableBluetooth();
        if (!context.mounted) return;
        if (!enabled) {
          _show(context, 'Turn on Bluetooth, then try again.');
          return;
        }
      }

      final printers = await _printer.getPrinters(
        printerType: PrinterType.bluetooth,
      );
      if (!context.mounted) return;
      if (printers.isEmpty) {
        _show(context, 'No paired thermal printer found. Pair it in Android Bluetooth settings first.');
        return;
      }
      _savedBluetoothAddress ??= await _loadSavedBluetoothAddress();
      if (!context.mounted) return;
      final remembered = _selectedBluetoothPrinter ??
          _printerForAddress(printers, _savedBluetoothAddress);
      final isRememberedPrinterAvailable = remembered != null &&
          printers.any((printer) => printer.bleAddress == remembered.bleAddress);
      final selected = isRememberedPrinterAvailable
          ? remembered
          : await showModalBottomSheet<Printer>(
              context: context,
              builder: (sheetContext) => SafeArea(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(sheetContext).height * .75,
                  ),
                  child: Column(
                    children: [
                      const ListTile(
                        title: Text('Choose thermal printer'),
                        subtitle: Text(
                          'Select a printer already paired with this phone.',
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: printers.length,
                          itemBuilder: (_, index) {
                            final printer = printers[index];
                            return ListTile(
                              leading: const Icon(Icons.print_outlined),
                              title: Text(
                                printer.name.isEmpty
                                    ? 'Thermal printer'
                                    : printer.name,
                              ),
                              subtitle: Text(printer.bleAddress),
                              onTap: () => Navigator.pop(sheetContext, printer),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
      if (selected == null) return;
      _selectedBluetoothPrinter = selected;
      _savedBluetoothAddress = selected.bleAddress;
      unawaited(_saveBluetoothAddress(selected.bleAddress));

      if (!context.mounted) return;
      _show(context, 'Connecting to ${_printerName(selected)}…');
      final connected = await _printer.connect(printer: selected);
      if (!connected) {
        _log('bluetooth_connection_failed', printer: _printerName(selected));
        if (context.mounted) {
          _show(
            context,
            'Could not connect to ${_printerName(selected)}. This printer may not support classic Bluetooth (SPP), or it may already be connected to another app.',
          );
        }
        return;
      }
      if (!await _printer.isConnected(printer: selected)) {
        _log('bluetooth_disconnected', printer: _printerName(selected));
        if (context.mounted) {
          _show(context, '${_printerName(selected)} disconnected before printing. Try again with the printer nearby.');
        }
        return;
      }
      await _printer.printBytes(bytes: bytes, printer: selected);
      if (context.mounted) {
        _show(context, 'Receipt sent to ${_printerName(selected)}.');
      }
    } on MissingPluginException {
      _log('native_printer_plugin_missing');
      if (context.mounted) {
        _show(
          context,
          'USB printing is not included in this installed app. Fully uninstall it, then install the newly rebuilt APK.',
        );
      }
    } on PlatformException catch (error) {
      _log('platform_error', message: '${error.code}: ${error.message ?? ''}');
      if (context.mounted) {
        _show(context, 'Printer error (${error.code}): ${error.message ?? 'unknown error'}');
      }
    } catch (error) {
      _log('print_error', message: '$error');
      if (context.mounted) {
        _show(context, 'Printing failed: $error');
      }
    }
  }

  static String _printerName(Printer printer) =>
      printer.name.isEmpty ? 'the printer' : printer.name;

  static void _log(
    String event, {
    String? printer,
    String? message,
  }) {
    unawaited(_writeLog(event, printer: printer, message: message));
  }

  static Future<void> _writeLog(
    String event, {
    String? printer,
    String? message,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('printer_logs').add({
        'event': event,
        'printer': ?printer,
        'message': ?message,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Diagnostics must never interrupt printing.
    }
  }

  static Printer? _printerForAddress(
    List<Printer> printers,
    String? address,
  ) {
    if (address == null || address.isEmpty) return null;
    for (final printer in printers) {
      if (printer.bleAddress == address) return printer;
    }
    return null;
  }

  static Future<List<Map<String, dynamic>>> _usbPrinters() async {
    try {
      final printers = await _usbChannel.invokeMethod<List<dynamic>>(
        'printers',
      );
      return (printers ?? [])
          .whereType<Map>()
          .map((printer) => Map<String, dynamic>.from(printer))
          .toList();
    } on MissingPluginException {
      return [];
    }
  }

  static Future<String?> _loadSavedBluetoothAddress() async {
    try {
      return await _usbChannel.invokeMethod<String>('preferredBluetooth');
    } on MissingPluginException {
      return null;
    }
  }

  static Future<void> _saveBluetoothAddress(String address) async {
    try {
      await _usbChannel.invokeMethod('setPreferredBluetooth', {
        'address': address,
      });
    } on MissingPluginException {
      // Old installed APKs do not include the optional native bridge.
    }
  }

  static Future<void> _clearSavedBluetoothAddress() async {
    try {
      await _usbChannel.invokeMethod('clearPreferredBluetooth');
    } on MissingPluginException {
      // Clearing is best-effort when the native bridge is unavailable.
    }
  }

  static Future<Map<String, dynamic>?> _chooseUsbPrinter(
    BuildContext context,
    List<Map<String, dynamic>> printers,
  ) => showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * .75,
        ),
        child: Column(
          children: [
            const ListTile(
              title: Text('Choose USB thermal printer'),
              subtitle: Text(
                'Select the printer connected through the USB cable.',
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: printers.length,
                itemBuilder: (_, index) {
                  final printer = printers[index];
                  return ListTile(
                    leading: const Icon(Icons.usb),
                    title: Text('${printer['name'] ?? 'USB printer'}'),
                    onTap: () => Navigator.pop(sheetContext, printer),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );

  static void _show(BuildContext context, String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
