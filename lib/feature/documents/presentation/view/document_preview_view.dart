import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:stephen_farmer/core/common/role_bg_color.dart';
import 'package:stephen_farmer/core/network/api_service/api_endpoints.dart';
import 'package:stephen_farmer/core/network/api_service/token_meneger.dart';
import 'package:stephen_farmer/feature/auth/presentation/controller/login_controller.dart';
import 'package:stephen_farmer/feature/documents/domain/entities/document_project_entity.dart';

class DocumentPreviewView extends StatefulWidget {
  const DocumentPreviewView({super.key, required this.item});

  final RecentDocumentEntity item;

  @override
  State<DocumentPreviewView> createState() => _DocumentPreviewViewState();
}

class _DocumentPreviewViewState extends State<DocumentPreviewView> {
  static const MethodChannel _nativeUrlOpenChannel = MethodChannel(
    'app.url_open/native',
  );
  late final Future<_DocumentPayload> _documentPayloadFuture;
  bool _pdfRenderFailed = false;

  @override
  void initState() {
    super.initState();
    final rawUrl = widget.item.fileUrl?.trim() ?? '';
    _documentPayloadFuture =
        _shouldPreferCloudinaryImagePreview(rawUrl, widget.item.mimeType)
        ? Future<_DocumentPayload>.value(_DocumentPayload.empty())
        : _isPdfDocument(rawUrl, widget.item.mimeType)
        ? _fetchDocumentPayload(rawUrl)
        : Future<_DocumentPayload>.value(_DocumentPayload.empty());
  }

  @override
  Widget build(BuildContext context) {
    final role = Get.find<LoginController>().role.value;
    final isInterior = RoleBgColor.isInterior(role);
    final bgColor = RoleBgColor.scaffoldColor(role);
    final titleColor = isInterior ? const Color(0xFF040404) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: titleColor,
        title: Text(
          'Document',
          style: GoogleFonts.manrope(
            color: titleColor,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.item.title,
                style: GoogleFonts.manrope(
                  color: titleColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.item.category} • ${widget.item.dateLabel}',
                style: GoogleFonts.manrope(
                  color: isInterior
                      ? const Color(0xFF46413A)
                      : const Color(0xFFD5DDE1),
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(child: _buildPreview(context, isInterior)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreview(BuildContext context, bool isInterior) {
    final url = widget.item.fileUrl?.trim() ?? '';
    if (url.isEmpty) {
      return _messageBox(
        isInterior: isInterior,
        text: 'No document URL found for this file.',
      );
    }

    if (_isPdfDocument(url, widget.item.mimeType)) {
      return _buildPdfPreview(isInterior);
    }

    if (_isImageDocument(url, widget.item.mimeType)) {
      return _buildResolvedImagePreview(url, isInterior);
    }

    if (_isPreviewableButUnsupportedImage(url, widget.item.mimeType)) {
      return _messageBox(
        isInterior: isInterior,
        text: 'This image format is not supported for inline preview.',
      );
    }

    if (_isOfficeOrTextDocument(url, widget.item.mimeType)) {
      return _messageBox(
        isInterior: isInterior,
        text: 'This file type cannot be previewed here. Use download/open instead.',
      );
    }

    return _messageBox(
      isInterior: isInterior,
      text: 'Preview not available for this file type.',
    );
  }

  Widget _buildResolvedImagePreview(String rawUrl, bool isInterior) {
    final resolved = _resolveImageUrl(rawUrl);
    if (resolved.isEmpty) {
      return _messageBox(
        isInterior: isInterior,
        text: 'No valid image URL found for this file.',
      );
    }

    return _buildImagePreview(resolved, isInterior);
  }

  Widget _buildImagePreview(String url, bool isInterior) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isInterior ? const Color(0xFFBFC3C5) : const Color(0xFF2D3840),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const Center(child: CircularProgressIndicator());
            },
            errorBuilder: (_, __, ___) {
              return _messageBox(
                isInterior: isInterior,
                text: 'Failed to load the selected document preview.',
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPdfPreview(bool isInterior) {
    final rawUrl = widget.item.fileUrl?.trim() ?? '';
    final resolvedUrl = _normalizePdfFetchUrl(
      _resolveDocumentUrl(rawUrl),
    );
    final fallbackPreviewUrl = _cloudinaryPdfPreviewImageUrl(
      rawUrl,
    );

    if (_shouldPreferCloudinaryImagePreview(rawUrl, widget.item.mimeType) &&
        fallbackPreviewUrl.isNotEmpty) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isInterior ? const Color(0xFFBFC3C5) : const Color(0xFF2D3840),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: _buildPdfImagePreviewWithAction(
            previewUrl: fallbackPreviewUrl,
            documentUrl: resolvedUrl,
            isInterior: isInterior,
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isInterior ? const Color(0xFFBFC3C5) : const Color(0xFF2D3840),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: FutureBuilder<_DocumentPayload>(
          future: _documentPayloadFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError ||
                !snapshot.hasData ||
                snapshot.data!.bytes.isEmpty) {
              if (fallbackPreviewUrl.isNotEmpty) {
                return _buildImagePreview(fallbackPreviewUrl, isInterior);
              }

              return _messageBox(
                isInterior: isInterior,
                text: 'Failed to load this PDF document.',
              );
            }

            final payload = snapshot.data!;
            if (_pdfRenderFailed) {
              return _messageBox(
                isInterior: isInterior,
                text: 'Failed to render this PDF document.',
              );
            }

            if (payload.isPdf) {
              return SfPdfViewer.memory(
                payload.bytes,
                canShowScrollHead: false,
                canShowScrollStatus: false,
                pageSpacing: 8,
                onDocumentLoadFailed: (_) {
                  if (!mounted) return;
                  setState(() {
                    _pdfRenderFailed = true;
                  });
                },
              );
            }

            if (payload.isImage) {
              return InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: Image.memory(
                  payload.bytes,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) {
                    return _messageBox(
                      isInterior: isInterior,
                      text: 'Failed to load the selected document preview.',
                    );
                  },
                ),
              );
            }

            return _messageBox(
              isInterior: isInterior,
              text: 'Preview not available for this document response.',
            );
          },
        ),
      ),
    );
  }

  Widget _buildPdfImagePreviewWithAction({
    required String previewUrl,
    required String documentUrl,
    required bool isInterior,
  }) {
    return Column(
      children: [
        Expanded(child: _buildImagePreview(previewUrl, isInterior)),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _openDocumentUrl(documentUrl),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isInterior ? const Color(0xFF040404) : Colors.white,
                foregroundColor:
                    isInterior ? Colors.white : const Color(0xFF040404),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Open Full PDF',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<_DocumentPayload> _fetchDocumentPayload(String url) async {
    final resolved = _normalizePdfFetchUrl(_resolveDocumentUrl(url));
    if (resolved.isEmpty) {
      throw Exception('Invalid PDF URL');
    }

    final uri = Uri.tryParse(resolved);
    if (uri == null || !uri.hasScheme) {
      throw Exception('Malformed PDF URL');
    }

    final token = await TokenManager.getToken();
    final response = await Dio().get<List<int>>(
      uri.toString(),
      options: Options(
        responseType: ResponseType.bytes,
        followRedirects: true,
        receiveTimeout: const Duration(seconds: 60),
        headers: {
          'Accept': 'application/pdf,*/*',
          ...?_authHeadersFor(uri, token),
        },
      ),
    );

    final data = response.data;
    if (data == null || data.isEmpty) {
      throw Exception('Empty PDF response');
    }

    final bytes = Uint8List.fromList(data);
    final contentType =
        response.headers.value(Headers.contentTypeHeader)?.toLowerCase() ?? '';

    if (_looksLikePdf(bytes) || contentType.contains('application/pdf')) {
      return _DocumentPayload.pdf(bytes);
    }

    if (_looksLikeImage(bytes) || contentType.startsWith('image/')) {
      return _DocumentPayload.image(bytes);
    }

    throw Exception('Unsupported document response');
  }

  String _resolveDocumentUrl(String raw) {
    final value = raw.trim().replaceAll('\\', '/');
    if (value.isEmpty || value.toLowerCase() == 'null') return '';
    final lower = value.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) return value;
    if (value.startsWith('//')) return 'https:$value';

    final origin = _apiOrigin();
    if (origin.isEmpty) return '';
    if (value.startsWith('/')) return '$origin$value';
    return '$origin/$value';
  }

  String _resolveImageUrl(String raw) {
    final resolved = _resolveDocumentUrl(raw);
    if (resolved.isEmpty) return '';

    final uri = Uri.tryParse(resolved);
    if (uri == null) return resolved;

    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();
    if (!host.contains('res.cloudinary.com')) {
      return resolved;
    }

    if (path.endsWith('.avif') && uri.path.contains('/upload/')) {
      final transformedPath = uri.path.replaceFirst(
        '/upload/',
        '/upload/f_auto,q_auto/',
      );
      return uri.replace(path: transformedPath).toString();
    }

    return resolved;
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

  Map<String, String>? _authHeadersFor(Uri uri, String? token) {
    final t = token?.trim() ?? '';
    if (t.isEmpty) return null;
    final apiHost = Uri.tryParse(_apiOrigin())?.host ?? '';
    if (apiHost.isEmpty || uri.host != apiHost) return null;
    return <String, String>{'Authorization': 'Bearer $t'};
  }

  bool _looksLikePdf(Uint8List bytes) {
    if (bytes.length < 5) return false;
    return bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46 &&
        bytes[4] == 0x2D;
  }

  bool _looksLikeImage(Uint8List bytes) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return true;
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return true;
    }
    if (bytes.length >= 6 &&
        bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46) {
      return true;
    }
    if (bytes.length >= 4 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46) {
      return true;
    }
    return false;
  }

  String _normalizePdfFetchUrl(String resolved) {
    if (resolved.isEmpty) return '';

    final uri = Uri.tryParse(resolved);
    if (uri == null) return resolved;

    final host = uri.host.toLowerCase();
    final path = uri.path;
    if (!host.contains('res.cloudinary.com') ||
        !path.toLowerCase().endsWith('.pdf') ||
        !path.contains('/upload/')) {
      return resolved;
    }

    if (path.contains('/raw/upload/')) {
      return resolved;
    }

    final rawPath = path.replaceFirst('/image/upload/', '/raw/upload/');
    return uri.replace(path: rawPath).toString();
  }

  String _cloudinaryPdfPreviewImageUrl(String raw) {
    final resolved = _resolveDocumentUrl(raw);
    if (resolved.isEmpty) return '';

    final uri = Uri.tryParse(resolved);
    if (uri == null) return '';

    final host = uri.host.toLowerCase();
    final path = uri.path;
    if (!host.contains('res.cloudinary.com') ||
        !path.toLowerCase().endsWith('.pdf') ||
        !path.contains('/upload/')) {
      return '';
    }

    final normalizedImagePath = path.contains('/raw/upload/')
        ? path.replaceFirst('/raw/upload/', '/image/upload/')
        : path;
    final transformedPath = normalizedImagePath.replaceFirst(
      '/upload/',
      '/upload/pg_1,f_jpg,q_auto/',
    );

    return uri.replace(path: transformedPath).toString();
  }

  Future<void> _openDocumentUrl(String rawUrl) async {
    final resolved = _normalizePdfFetchUrl(_resolveDocumentUrl(rawUrl));
    if (resolved.isEmpty) {
      Get.snackbar('Preview unavailable', 'No valid document URL found.');
      return;
    }

    final uri = Uri.tryParse(resolved);
    if (uri == null) {
      Get.snackbar('Preview unavailable', 'Invalid document URL.');
      return;
    }

    final opened =
        await _nativeUrlOpenChannel.invokeMethod<bool>('openUrl', <String, dynamic>{
          'url': uri.toString(),
        }) ??
        false;
    if (!opened) {
      Get.snackbar('Preview unavailable', 'Failed to open this PDF.');
    }
  }

  Widget _messageBox({required bool isInterior, required String text}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isInterior ? const Color(0xFFE0DFDD) : const Color(0xFF111A22),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isInterior ? const Color(0xFFBFC3C5) : const Color(0xFF2D3840),
        ),
      ),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            color: isInterior ? const Color(0xFF46413A) : const Color(0xFFD5DDE1),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  bool _isPdfDocument(String url, String? mimeType) {
    final mime = (mimeType ?? '').toLowerCase();
    if (mime == 'application/pdf') return true;

    final lower = url.toLowerCase();
    return lower.endsWith('.pdf') || lower.contains('.pdf?');
  }

  bool _shouldPreferCloudinaryImagePreview(String url, String? mimeType) {
    if (!_isPdfDocument(url, mimeType)) return false;
    final resolved = _resolveDocumentUrl(url);
    if (resolved.isEmpty) return false;

    final uri = Uri.tryParse(resolved);
    if (uri == null) return false;

    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();
    return host.contains('res.cloudinary.com') &&
        path.contains('/image/upload/') &&
        path.endsWith('.pdf');
  }

  bool _isImageDocument(String url, String? mimeType) {
    final mime = (mimeType ?? '').toLowerCase();
    if (mime.startsWith('image/')) return true;

    final lower = url.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.avif') ||
        lower.endsWith('.heic') ||
        lower.endsWith('.heif') ||
        lower.endsWith('.bmp') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif');
  }

  bool _isPreviewableButUnsupportedImage(String url, String? mimeType) {
    final mime = (mimeType ?? '').toLowerCase();
    if (mime == 'image/svg+xml' || mime == 'image/tiff') return true;

    final lower = url.toLowerCase();
    return lower.endsWith('.svg') ||
        lower.endsWith('.tif') ||
        lower.endsWith('.tiff');
  }

  bool _isOfficeOrTextDocument(String url, String? mimeType) {
    final mime = (mimeType ?? '').toLowerCase();
    if (mime.contains('word') ||
        mime.contains('excel') ||
        mime.contains('spreadsheet') ||
        mime.contains('powerpoint') ||
        mime.contains('presentation') ||
        mime.contains('text/') ||
        mime == 'application/msword' ||
        mime ==
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document' ||
        mime == 'application/vnd.ms-excel' ||
        mime ==
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' ||
        mime == 'application/vnd.ms-powerpoint' ||
        mime ==
            'application/vnd.openxmlformats-officedocument.presentationml.presentation' ||
        mime == 'text/plain' ||
        mime == 'text/csv') {
      return true;
    }

    final lower = url.toLowerCase();
    return lower.endsWith('.doc') ||
        lower.endsWith('.docx') ||
        lower.endsWith('.xls') ||
        lower.endsWith('.xlsx') ||
        lower.endsWith('.ppt') ||
        lower.endsWith('.pptx') ||
        lower.endsWith('.txt') ||
        lower.endsWith('.csv');
  }
}

class _DocumentPayload {
  const _DocumentPayload._(this.bytes, this.kind);

  _DocumentPayload.empty() : this._(Uint8List(0), _DocumentKind.unknown);

  factory _DocumentPayload.pdf(Uint8List bytes) {
    return _DocumentPayload._(bytes, _DocumentKind.pdf);
  }

  factory _DocumentPayload.image(Uint8List bytes) {
    return _DocumentPayload._(bytes, _DocumentKind.image);
  }

  final Uint8List bytes;
  final _DocumentKind kind;

  bool get isPdf => kind == _DocumentKind.pdf;
  bool get isImage => kind == _DocumentKind.image;
}

enum _DocumentKind { unknown, pdf, image }
