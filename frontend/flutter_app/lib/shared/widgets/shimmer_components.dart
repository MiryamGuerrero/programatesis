import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class NutriShimmer extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const NutriShimmer({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade50,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: borderRadius ?? BorderRadius.circular(8),
        ),
      ),
    );
  }
}

class NutriResumenCardShimmer extends StatelessWidget {
  const NutriResumenCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          NutriShimmer(width: 80, height: 10),
          SizedBox(height: 8),
          NutriShimmer(width: 40, height: 22),
        ],
      ),
    );
  }
}

class NutriTableShimmer extends StatelessWidget {
  final int rows;
  final int columns;

  const NutriTableShimmer({
    super.key,
    this.rows = 5,
    this.columns = 5,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          height: 56,
          color: const Color(0xFFF1F5F9),
          child: Row(
            children: List.generate(
              columns,
              (index) => Expanded(
                child: Center(
                  child: NutriShimmer(
                    width: index == 0 ? 100 : 60,
                    height: 12,
                  ),
                ),
              ),
            ),
          ),
        ),
        // Rows
        ...List.generate(
          rows,
          (index) => Container(
            height: 52,
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFF1F5F9)),
              ),
            ),
            child: Row(
              children: List.generate(
                columns,
                (colIndex) => Expanded(
                  child: Center(
                    child: NutriShimmer(
                      width: colIndex == 0 ? 120 : 80,
                      height: 10,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class NutriTableRowShimmer extends StatelessWidget {
  final int columns;

  const NutriTableRowShimmer({super.key, this.columns = 5});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        columns,
        (index) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: NutriShimmer(
              width: double.infinity,
              height: 12,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }
}

class NutriCardShimmer extends StatelessWidget {
  final double height;
  const NutriCardShimmer({super.key, this.height = 100});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const NutriShimmer(width: 120, height: 12),
          const SizedBox(height: 12),
          const NutriShimmer(width: 80, height: 24),
        ],
      ),
    );
  }
}

class NutriRecetaCardShimmer extends StatelessWidget {
  const NutriRecetaCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NutriShimmer(
            width: double.infinity,
            height: 200,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NutriShimmer(width: 150, height: 14),
                SizedBox(height: 12),
                NutriShimmer(width: double.infinity, height: 10),
                SizedBox(height: 8),
                NutriShimmer(width: 200, height: 10),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    NutriShimmer(width: 80, height: 24),
                    NutriShimmer(width: 80, height: 24),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class NutriEtiquetaCardShimmer extends StatelessWidget {
  const NutriEtiquetaCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              NutriShimmer(width: 150, height: 16),
              NutriShimmer(width: 20, height: 20),
            ],
          ),
          SizedBox(height: 12),
          NutriShimmer(width: double.infinity, height: 12),
          SizedBox(height: 8),
          NutriShimmer(width: 200, height: 12),
          SizedBox(height: 20),
          NutriShimmer(width: 100, height: 10),
          SizedBox(height: 8),
          NutriShimmer(width: double.infinity, height: 40),
          Spacer(),
          Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              NutriShimmer(width: 80, height: 10),
              Row(
                children: [
                  NutriShimmer(width: 24, height: 24),
                  SizedBox(width: 12),
                  NutriShimmer(width: 24, height: 24),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class NutriGridShimmer extends StatelessWidget {
  final int itemCount;
  final int crossAxisCount;
  final double mainAxisExtent;

  const NutriGridShimmer({
    super.key,
    this.itemCount = 6,
    this.crossAxisCount = 3,
    this.mainAxisExtent = 480,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 24,
        mainAxisSpacing: 24,
        mainAxisExtent: mainAxisExtent,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NutriShimmer(
              width: double.infinity,
              height: 200,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  NutriShimmer(width: 150, height: 14),
                  SizedBox(height: 12),
                  NutriShimmer(width: double.infinity, height: 10),
                  SizedBox(height: 8),
                  NutriShimmer(width: 200, height: 10),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      NutriShimmer(width: 80, height: 24),
                      NutriShimmer(width: 80, height: 24),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
