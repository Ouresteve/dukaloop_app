import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/models.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;

  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final stock = product.totalStock ?? 0;
    final invested = product.totalCost ?? 0;
    final expected = product.expectedReturn ?? 0;

    // Detect very small screens
    final isSmall = MediaQuery.of(context).size.width < 360;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: EdgeInsets.all(isSmall ? 10 : 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon + Name
              Row(
                children: [
                  Container(
                    width: isSmall ? 32 : 36,
                    height: isSmall ? 32 : 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.inventory_2_rounded,
                      color: AppColors.primary,
                      size: isSmall ? 16 : 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isSmall ? 12.5 : 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // Stock
              Text(
                'Stock: ${Formatters.number(stock)}',
                style: TextStyle(
                  fontSize: isSmall ? 11 : 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),

              // Invested
              Text(
                Formatters.currency(invested),
                style: TextStyle(
                  fontSize: isSmall ? 12 : 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 1),

              // Expected Return
              Text(
                'Exp: ${Formatters.currency(expected)}',
                style: TextStyle(
                  fontSize: isSmall ? 10.5 : 11.5,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}