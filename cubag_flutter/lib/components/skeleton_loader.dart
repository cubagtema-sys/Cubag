import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class SkeletonLoader extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonLoader({
    super.key,
    this.width = double.infinity,
    this.height = 20,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
      highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonLoader(height: 160, borderRadius: 16),
          const SizedBox(height: 24),
          const SkeletonLoader(width: 150, height: 24),
          const SizedBox(height: 16),
          const SkeletonLoader(height: 100, borderRadius: 12),
          const SizedBox(height: 16),
          const SkeletonLoader(height: 100, borderRadius: 12),
          const SizedBox(height: 24),
          const SkeletonLoader(width: 150, height: 24),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: SkeletonLoader(height: 80, borderRadius: 12)),
              const SizedBox(width: 12),
              Expanded(child: SkeletonLoader(height: 80, borderRadius: 12)),
            ],
          )
        ],
      ),
    );
  }
}
