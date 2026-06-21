import 'dart:async';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../features/auth/domain/entities/app_user.dart';
import '../../features/groups/domain/repositories/group_repository.dart';
import '../../features/groups/presentation/screens/group_chat_screen.dart';

class InAppNotificationBanner extends StatefulWidget {
  const InAppNotificationBanner({
    super.key,
    required this.user,
    required this.groupRepository,
    required this.child,
  });

  final AppUser user;
  final GroupRepository groupRepository;
  final Widget child;

  @override
  State<InAppNotificationBanner> createState() =>
      _InAppNotificationBannerState();
}

class _InAppNotificationBannerState extends State<InAppNotificationBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _fadeAnim;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  final Map<String, Timestamp?> _lastSeen = {};

  String? _bannerGroupId;
  String? _bannerGroupName;
  Map<String, dynamic>? _bannerGroupData;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
      reverseDuration: const Duration(milliseconds: 260),
    );
    _slideAnim = Tween<Offset>(begin: const Offset(0, -1.35), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          ),
        );
    _fadeAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.72, curve: Curves.easeOut),
      reverseCurve: Curves.easeIn,
    );
    _startListening();
  }

  void _startListening() {
    _sub = widget.groupRepository.streamGroupsForUser(widget.user).listen((
      snapshot,
    ) {
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final Timestamp? lastMsgTime = data['lastMessageTime'] as Timestamp?;
        final String groupId = doc.id;
        final String groupName = (data['name'] as String?) ?? 'Group';

        if (_lastSeen.containsKey(groupId)) {
          final Timestamp? prev = _lastSeen[groupId];
          if (lastMsgTime != null &&
              (prev == null || lastMsgTime.compareTo(prev) > 0)) {
            _lastSeen[groupId] = lastMsgTime;
            // Don't show if we're already in this group
            final String? lastSenderUid =
                data['lastMessageSenderUid'] as String?;
            if (_bannerGroupId != groupId && lastSenderUid != widget.user.uid) {
              _showBanner(
                groupId: groupId,
                groupName: groupName,
                groupData: data,
              );
            }
          }
        } else {
          _lastSeen[groupId] = lastMsgTime;
        }
      }
    });
  }

  void _showBanner({
    required String groupId,
    required String groupName,
    required Map<String, dynamic> groupData,
  }) {
    _dismissTimer?.cancel();
    setState(() {
      _bannerGroupId = groupId;
      _bannerGroupName = groupName;
      _bannerGroupData = groupData;
    });
    _controller.forward(from: 0);
    _dismissTimer = Timer(const Duration(seconds: 3), _dismiss);
  }

  void _dismiss() {
    _controller.reverse().then((_) {
      if (mounted) {
        setState(() {
          _bannerGroupId = null;
          _bannerGroupName = null;
          _bannerGroupData = null;
        });
      }
    });
  }

  void _onTap() {
    _dismissTimer?.cancel();
    final groupId = _bannerGroupId;
    final groupData = _bannerGroupData;
    _dismiss();
    if (groupId == null || groupData == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GroupChatScreen(
          groupId: groupId,
          groupData: groupData,
          user: widget.user,
          groupRepository: widget.groupRepository,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    _controller.dispose();
    _dismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;
    final bool isDark = theme.brightness == Brightness.dark;
    final Color foreground = isDark
        ? Colors.white.withValues(alpha: 0.96)
        : colorScheme.onSurface;
    final Color glassTint = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Color.lerp(
            Colors.white,
            Colors.blue.shade50,
            0.30,
          )!.withValues(alpha: 0.46);
    final BorderRadius bannerRadius = BorderRadius.circular(27);
    final ImageFilter glassFilter = ImageFilter.compose(
      inner: ImageFilter.blur(sigmaX: 28, sigmaY: 28, tileMode: TileMode.clamp),
      outer: _vibrancyFilter(
        saturation: isDark ? 1.22 : 1.65,
        brightness: isDark ? 16 : 8,
      ),
    );

    // Either a group photo or a private-chat profile photo — same field,
    // the banner doesn't need to know which, just whether one exists.
    final String? avatarUrl = _bannerGroupData?['photoUrl'] as String?;

    return Stack(
      children: [
        widget.child,
        if (_bannerGroupId != null)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            right: 8,
            child: SlideTransition(
              position: _slideAnim,
              child: FadeTransition(
                opacity: _fadeAnim,
                child: GestureDetector(
                  onTap: _onTap,
                  child: ClipRRect(
                    borderRadius: bannerRadius,
                    child: BackdropFilter(
                      filter: glassFilter,
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 72),
                        padding: const EdgeInsets.fromLTRB(14, 12, 13, 12),
                        decoration: BoxDecoration(
                          color: glassTint,
                          borderRadius: bannerRadius,
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.26)
                                : Colors.white.withValues(alpha: 0.78),
                            width: 0.9,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: isDark ? 0.34 : 0.15,
                              ),
                              blurRadius: 34,
                              spreadRadius: -9,
                              offset: const Offset(0, 20),
                            ),
                            BoxShadow(
                              color: Colors.white.withValues(
                                alpha: isDark ? 0.10 : 0.38,
                              ),
                              blurRadius: 1,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            ClipOval(
                              child: avatarUrl != null && avatarUrl.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: avatarUrl,
                                      width: 42,
                                      height: 42,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, _, _) =>
                                          _fallbackAvatar(colorScheme),
                                    )
                                  : _fallbackAvatar(colorScheme),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'You have a new message',
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: foreground,
                                      fontWeight: FontWeight.w400,
                                      fontSize: 13.5,
                                      height: 1.16,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _bannerGroupName ?? '',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: foreground.withValues(
                                        alpha: isDark ? 0.74 : 0.66,
                                      ),
                                      fontSize: 12,
                                      height: 1.12,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 14,
                              color: foreground.withValues(
                                alpha: isDark ? 0.50 : 0.40,
                              ),
                            ),
                          ],
                        ),
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

  Widget _fallbackAvatar(ColorScheme colorScheme) {
    return Container(
      width: 42,
      height: 42,
      color: colorScheme.primary,
      child: Icon(
        Icons.chat_bubble_rounded,
        color: colorScheme.onPrimary,
        size: 21,
      ),
    );
  }

  ImageFilter _vibrancyFilter({
    required double saturation,
    required double brightness,
  }) {
    const double redLuminance = 0.2126;
    const double greenLuminance = 0.7152;
    const double blueLuminance = 0.0722;
    final double inverseSaturation = 1 - saturation;

    return ColorFilter.matrix(<double>[
      inverseSaturation * redLuminance + saturation,
      inverseSaturation * greenLuminance,
      inverseSaturation * blueLuminance,
      0,
      brightness,
      inverseSaturation * redLuminance,
      inverseSaturation * greenLuminance + saturation,
      inverseSaturation * blueLuminance,
      0,
      brightness,
      inverseSaturation * redLuminance,
      inverseSaturation * greenLuminance,
      inverseSaturation * blueLuminance + saturation,
      0,
      brightness,
      0,
      0,
      0,
      1,
      0,
    ]);
  }
}
