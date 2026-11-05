import 'package:flutter/material.dart';

import '../../features/inventory/domain/models/product.dart';
import '../theme/app_theme.dart';

/// A searchable picker for choosing a product without scrolling through a
/// long dropdown list.
class ProductSearchField extends StatelessWidget {
  const ProductSearchField({
    super.key,
    required this.products,
    required this.language,
    required this.onSelected,
    this.selected,
    this.subtitle,
  });

  final List<Product> products;
  final ProductNameLanguage language;
  final Product? selected;
  final String Function(Product)? subtitle;
  final ValueChanged<Product> onSelected;

  @override
  Widget build(BuildContext context) => Autocomplete<Product>(
    key: ValueKey(selected?.id),
    initialValue: TextEditingValue(text: selected?.nameFor(language) ?? ''),
    displayStringForOption: (product) => product.nameFor(language),
    optionsBuilder: (value) {
      final query = value.text.trim().toLowerCase();
      final matches = products.where((product) {
        if (query.isEmpty) return true;
        return '${product.productNumber ?? ''} ${product.name} '
                '${product.tamilName ?? ''} ${product.marathiName ?? ''} '
                '${product.category}'
            .toLowerCase()
            .contains(query);
      }).toList();
      matches.sort((a, b) => (a.productNumber ?? 1 << 31).compareTo(
            b.productNumber ?? 1 << 31,
          ));
      return matches;
    },
    onSelected: onSelected,
    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) => TextField(
      controller: controller,
      focusNode: focusNode,
      decoration: const InputDecoration(
        labelText: 'Product',
        hintText: 'Search product or number',
        prefixIcon: Icon(Icons.search),
        border: OutlineInputBorder(),
      ),
    ),
    optionsViewBuilder: (context, onOptionSelected, options) => Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 280, maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 4),
            shrinkWrap: true,
            children: options.map((product) => ListTile(
              leading: _ProductImage(product: product),
              title: Text(
                '${product.productNumber == null ? '' : '#${product.productNumber} '}${product.nameFor(language)}',
              ),
              subtitle: Text(subtitle?.call(product) ?? product.category),
              onTap: () => onOptionSelected(product),
            )).toList(),
          ),
        ),
      ),
    ),
  );
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) => Container(
    width: 36,
    height: 36,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: primary.withValues(alpha: .10),
      borderRadius: BorderRadius.circular(10),
    ),
    child: product.imageUrl == null || product.imageUrl!.isEmpty
        ? const Icon(Icons.inventory_2_outlined, color: primary, size: 20)
        : Image.network(
            product.imageUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                const Icon(Icons.inventory_2_outlined, color: primary, size: 20),
          ),
  );
}
