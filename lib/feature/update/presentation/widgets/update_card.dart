import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:stephen_farmer/core/network/api_service/api_endpoints.dart';
import 'package:stephen_farmer/core/network/api_service/token_meneger.dart';
import 'package:stephen_farmer/core/utils/images.dart';

import '../../data/model/update_model.dart';

class UpdatePostCard extends StatelessWidget {
  const UpdatePostCard({
    super.key,
    required this.item,
    this.isInteriorTheme = false,
    required this.onLike,
    required this.onComment,
    required this.onShare,
  });

  final UpdateModel item;
  final bool isInteriorTheme;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isInteriorTheme
        ? Colors.transparent
        : Colors.transparent;
    final borderColor = isInteriorTheme
        ? Colors.transparent
        : Colors.white.withValues(alpha: .08);
    final primaryTextColor = isInteriorTheme
        ? const Color(0xFF1B1B1B)
        : Colors.white;
    final secondaryTextColor = isInteriorTheme
        ? const Color(0xFF6F6B62)
        : Colors.white.withValues(alpha: .55);
    final contentTextColor = isInteriorTheme
        ? const Color(0xFF1D1D1D)
        : Colors.white.withValues(alpha: .85);
    final metaStatColor = isInteriorTheme
        ? const Color(0xFFF3EEDD)
        : Colors.white.withValues(alpha: .65);

    final fallbackImage =
        'https://images.unsplash.com/photo-1505693416388-ac5ce068fe85?w=900&auto=format&fit=crop';

    final postImages = _collectPostImageUrls(
      imageUrls: item.imageUrls,
      thumbnailUrl: item.thumbnailUrl,
      fallbackImage: fallbackImage,
    );

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _AuthorAvatar(
                imageUrl: item.authorAvatar,
                radius: 24,
                isInteriorTheme: isInteriorTheme,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.authorName,
                      style: GoogleFonts.manrope(
                        color: primaryTextColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 1,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.authorRole.toUpperCase()}  ·  ${_timeAgo(item.createdAt)}',
                      style: TextStyle(
                        color: secondaryTextColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: .4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _ExpandableDescriptionText(
            text: item.description.trim().isEmpty
                ? item.title
                : item.description,
            textColor: contentTextColor,
          ),
          const SizedBox(height: 12),
          _UpdateMediaGallery(
            imageUrls: postImages,
            fallbackImage: fallbackImage,
            borderRadius: 10,
            isInteriorTheme: isInteriorTheme,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                item.isLiked ? Icons.favorite : Icons.favorite_border,
                color: item.isLiked ? Colors.red : metaStatColor,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                '${item.likeCount}',
                style: TextStyle(
                  color: isInteriorTheme ? Colors.white : Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                '${item.commentCount} Comments',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${item.shareCount} Shares',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _ActionBtn(
                icon: item.isLiked ? Icons.favorite : Icons.favorite_border,
                label: 'Heart',
                onTap: onLike,
                isInteriorTheme: isInteriorTheme,
              ),
              _ActionBtn(
                assetPath: AssetsImages.comments,
                label: 'Comment',
                onTap: onComment,
                isInteriorTheme: isInteriorTheme,
              ),
              _ActionBtn(
                icon: Icons.share_outlined,
                label: 'Share',
                onTap: onShare,
                isInteriorTheme: isInteriorTheme,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UpdateMediaGallery extends StatefulWidget {
  const _UpdateMediaGallery({
    required this.imageUrls,
    required this.fallbackImage,
    required this.borderRadius,
    required this.isInteriorTheme,
  });

  final List<String> imageUrls;
  final String fallbackImage;
  final double borderRadius;
  final bool isInteriorTheme;

  @override
  State<_UpdateMediaGallery> createState() => _UpdateMediaGalleryState();
}

class _UpdateMediaGalleryState extends State<_UpdateMediaGallery> {
  late final Future<String?> _tokenFuture;

  @override
  void initState() {
    super.initState();
    _tokenFuture = TokenManager.getToken();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _tokenFuture,
      builder: (context, snapshot) {
        final token = snapshot.data?.trim() ?? '';
        final headers = token.isEmpty
            ? null
            : <String, String>{'Authorization': 'Bearer $token'};

        return _buildLayout(headers);
      },
    );
  }

  Widget _buildLayout(Map<String, String>? headers) {
    const gap = 4.0;
    final urls = widget.imageUrls;
    final count = urls.length;

    Widget imageTile(String url, {int? extraCount}) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            url,
            fit: BoxFit.cover,
            headers: headers,
            errorBuilder: (_, __, ___) => _imageFallback(),
          ),
          if (extraCount != null && extraCount > 0)
            Container(
              color: Colors.black.withValues(alpha: .45),
              alignment: Alignment.center,
              child: Text(
                '+$extraCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 24,
                ),
              ),
            ),
        ],
      );
    }

    Widget rowTiles(List<Widget> children) {
      return Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            Expanded(child: children[i]),
            if (i != children.length - 1) const SizedBox(width: gap),
          ],
        ],
      );
    }

    Widget layout;
    double height;

    if (count <= 1) {
      height = 220;
      layout = imageTile(urls.first);
    } else if (count == 2) {
      height = 220;
      layout = rowTiles([
        imageTile(urls[0]),
        imageTile(urls[1]),
      ]);
    } else if (count == 3) {
      height = 240;
      layout = Column(
        children: [
          Expanded(child: imageTile(urls[0])),
          const SizedBox(height: gap),
          Expanded(
            child: rowTiles([
              imageTile(urls[1]),
              imageTile(urls[2]),
            ]),
          ),
        ],
      );
    } else if (count == 4) {
      height = 240;
      layout = Column(
        children: [
          Expanded(
            child: rowTiles([
              imageTile(urls[0]),
              imageTile(urls[1]),
            ]),
          ),
          const SizedBox(height: gap),
          Expanded(
            child: rowTiles([
              imageTile(urls[2]),
              imageTile(urls[3]),
            ]),
          ),
        ],
      );
    } else {
      height = 250;
      final extras = count - 5;
      layout = Column(
        children: [
          Expanded(
            child: rowTiles([
              imageTile(urls[0]),
              imageTile(urls[1]),
            ]),
          ),
          const SizedBox(height: gap),
          Expanded(
            child: rowTiles([
              imageTile(urls[2]),
              imageTile(urls[3]),
              imageTile(urls[4], extraCount: extras > 0 ? extras : null),
            ]),
          ),
        ],
      );
    }

    return SizedBox(
      height: height,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: ColoredBox(
          color: widget.isInteriorTheme
              ? const Color(0xFFE7E1D5)
              : Colors.black.withValues(alpha: .18),
          child: layout,
        ),
      ),
    );
  }

  Widget _imageFallback() {
    return Container(
      color: widget.isInteriorTheme
          ? const Color(0xFFDCD5C6)
          : Colors.white.withValues(alpha: .08),
      alignment: Alignment.center,
      child: Icon(
        Icons.image_not_supported_outlined,
        color: widget.isInteriorTheme
            ? const Color(0xFF7B6F5C)
            : Colors.white.withValues(alpha: .75),
        size: 22,
      ),
    );
  }
}

class _AuthorAvatar extends StatelessWidget {
  const _AuthorAvatar({
    required this.imageUrl,
    required this.radius,
    required this.isInteriorTheme,
  });

  final String? imageUrl;
  final double radius;
  final bool isInteriorTheme;

  @override
  Widget build(BuildContext context) {
    final url = _resolveMediaUrl(imageUrl ?? '');
    final diameter = radius * 2;

    if (url.isNotEmpty) {
      return ClipOval(
        child: _AuthorizedAvatarImage(
          imageUrl: url,
          width: diameter,
          height: diameter,
          fallback: _buildPlaceholder(),
        ),
      );
    }

    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    final diameter = radius * 2;
    return ClipOval(
      child: Image.asset(
        AssetsImages.placeholder,
        width: diameter,
        height: diameter,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: diameter,
          height: diameter,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isInteriorTheme
                ? const Color(0xFFD7CCBA)
                : const Color(0xFFD9CFF0),
          ),
          child: Icon(
            Icons.person_rounded,
            size: radius,
            color: isInteriorTheme
                ? const Color(0xFF655B4E)
                : const Color(0xFF7D7390),
          ),
        ),
      ),
    );
  }
}

class _AuthorizedAvatarImage extends StatefulWidget {
  const _AuthorizedAvatarImage({
    required this.imageUrl,
    required this.width,
    required this.height,
    required this.fallback,
  });

  final String imageUrl;
  final double width;
  final double height;
  final Widget fallback;

  @override
  State<_AuthorizedAvatarImage> createState() => _AuthorizedAvatarImageState();
}

class _AuthorizedAvatarImageState extends State<_AuthorizedAvatarImage> {
  late final Future<String?> _tokenFuture;

  @override
  void initState() {
    super.initState();
    _tokenFuture = TokenManager.getToken();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _tokenFuture,
      builder: (context, snapshot) {
        final token = snapshot.data?.trim() ?? '';
        final headers = token.isEmpty
            ? null
            : <String, String>{'Authorization': 'Bearer $token'};

        return Image.network(
          widget.imageUrl,
          width: widget.width,
          height: widget.height,
          fit: BoxFit.cover,
          headers: headers,
          errorBuilder: (_, __, ___) => widget.fallback,
        );
      },
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData? icon;
  final String? assetPath;
  final String label;
  final VoidCallback onTap;
  final bool isInteriorTheme;

  const _ActionBtn({
    this.icon,
    this.assetPath,
    required this.label,
    required this.onTap,
    this.isInteriorTheme = false,
  }) : assert(icon != null || assetPath != null);

  @override
  Widget build(BuildContext context) {
    const actionColor = Color(0xFFD7C5A4);

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
        child: Row(
          children: [
            if (assetPath != null)
              Image.asset(assetPath!, width: 18, height: 18, color: actionColor)
            else
              Icon(icon, color: actionColor, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: actionColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpandableDescriptionText extends StatefulWidget {
  const _ExpandableDescriptionText({
    required this.text,
    required this.textColor,
  });

  final String text;
  final Color textColor;

  @override
  State<_ExpandableDescriptionText> createState() =>
      _ExpandableDescriptionTextState();
}

class _ExpandableDescriptionTextState
    extends State<_ExpandableDescriptionText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.manrope(
      color: widget.textColor,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.35,
      letterSpacing: 0,
    );

    final maxWidth = MediaQuery.of(context).size.width - 32;
    final textPainter = TextPainter(
      text: TextSpan(text: widget.text, style: style),
      maxLines: 2,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);

    final hasOverflow = textPainter.didExceedMaxLines;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.text,
          textAlign: TextAlign.justify,
          maxLines: _expanded ? null : 2,
          overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
          style: style,
        ),
        if (hasOverflow)
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _expanded ? 'Show less' : 'Show more',
                style: GoogleFonts.manrope(
                  color: const Color(0xFFD7C5A4),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

String _timeAgo(DateTime dateTime) {
  final now = DateTime.now();
  final diff = now.difference(dateTime);

  if (diff.inMinutes < 1) return 'NOW';
  if (diff.inHours < 1) return '${diff.inMinutes}M AGO';
  if (diff.inDays < 1) return '${diff.inHours}H AGO';
  return '${diff.inDays}D AGO';
}

List<String> _collectPostImageUrls({
  required List<String> imageUrls,
  required String? thumbnailUrl,
  required String fallbackImage,
}) {
  final resolved = <String>[];
  final seen = <String>{};

  void add(String rawUrl) {
    final normalized = _resolveMediaUrl(rawUrl);
    if (normalized.isEmpty) return;
    if (seen.add(normalized)) {
      resolved.add(normalized);
    }
  }

  for (final imageUrl in imageUrls) {
    add(imageUrl);
  }

  if (resolved.isEmpty &&
      thumbnailUrl != null &&
      thumbnailUrl.trim().isNotEmpty) {
    add(thumbnailUrl);
  }

  if (resolved.isEmpty) {
    resolved.add(fallbackImage);
  }

  return resolved;
}

String _resolveMediaUrl(String raw) {
  final value = raw.trim().replaceAll('\\', '/');
  if (value.isEmpty || value.toLowerCase() == 'null') return '';

  if (value.startsWith('{') && value.contains('url:')) {
    final match = RegExp(r'url:\s*([^,}]+)').firstMatch(value);
    final extracted = match?.group(1)?.trim() ?? '';
    if (extracted.isEmpty) return '';
    return _resolveMediaUrl(extracted);
  }

  final lower = value.toLowerCase();
  if (lower.startsWith('http://') || lower.startsWith('https://')) {
    return value;
  }
  if (value.startsWith('//')) return 'https:$value';

  final origin = _apiOrigin();
  if (origin.isEmpty) return value;
  if (value.startsWith('/')) return '$origin$value';
  return '$origin/$value';
}

String _apiOrigin() {
  final trimmed = baseUrl.trim();
  if (trimmed.isEmpty) return '';
  final normalized = trimmed.replaceFirst(RegExp(r'/api/v\d+/?$'), '');
  final uri = Uri.tryParse(normalized);
  if (uri == null || uri.host.isEmpty) return normalized;

  var host = uri.host;
  if (!kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      (host == 'localhost' || host == '127.0.0.1')) {
    host = '10.0.2.2';
  }

  return Uri(
    scheme: uri.scheme,
    host: host,
    port: uri.hasPort ? uri.port : null,
  ).toString();
}
