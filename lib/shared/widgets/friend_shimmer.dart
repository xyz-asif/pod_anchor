import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';

/// Shimmer loading widget for friends list items
class FriendShimmer extends StatelessWidget {
  const FriendShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16.w,
          vertical: 4.h,
        ),
        leading: CircleAvatar(
          radius: 24.r,
          backgroundColor: Colors.white,
        ),
        title: Container(
          height: 16.h,
          width: 120.w,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4.r),
          ),
        ),
        subtitle: Container(
          height: 12.h,
          width: 80.w,
          margin: EdgeInsets.only(top: 4.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4.r),
          ),
        ),
        trailing: Container(
          width: 20.r,
          height: 20.r,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

/// Shimmer loading widget for pending requests list items
class PendingRequestShimmer extends StatelessWidget {
  const PendingRequestShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16.w,
          vertical: 4.h,
        ),
        leading: CircleAvatar(
          radius: 22.r,
          backgroundColor: Colors.white,
        ),
        title: Container(
          height: 16.h,
          width: 140.w,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4.r),
          ),
        ),
        subtitle: Container(
          height: 12.h,
          width: 100.w,
          margin: EdgeInsets.only(top: 4.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4.r),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28.r,
              height: 28.r,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: 8.w),
            Container(
              width: 28.r,
              height: 28.r,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
