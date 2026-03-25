// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:math' as math;

class WebFaviconBadge {
  WebFaviconBadge();

  String? _originalHref;
  bool _hasAttention = false;

  void setHasAttention(bool hasAttention) {
    if (!_ensureOriginalHref()) return;
    if (_hasAttention == hasAttention) return;
    _hasAttention = hasAttention;
    if (_hasAttention) {
      _applyBadge();
    } else {
      _restoreOriginal();
    }
  }

  bool _ensureOriginalHref() {
    if (_originalHref != null) return true;
    final link = _findOrCreateFaviconLink();
    if (link == null) return false;
    _originalHref = link.href.isNotEmpty ? link.href : 'favicon.png';
    return true;
  }

  html.LinkElement? _findOrCreateFaviconLink() {
    final doc = html.document;
    final existing =
        doc.querySelector("link[rel*='icon']") as html.LinkElement?;
    if (existing != null) {
      return existing;
    }
    final head = doc.head;
    if (head == null) return null;
    final link = html.LinkElement()
      ..rel = 'icon'
      ..type = 'image/png'
      ..href = 'favicon.png';
    head.append(link);
    return link;
  }

  Future<void> _applyBadge() async {
    final link = _findOrCreateFaviconLink();
    final href = _originalHref;
    if (link == null || href == null || href.isEmpty) return;

    final img = html.ImageElement(src: href);
    try {
      await img.onLoad.first;
    } catch (_) {
      // If the favicon fails to load, fall back to a blank canvas.
    }
    final width = (img.width ?? 0) > 0 ? img.width! : 64;
    final height = (img.height ?? 0) > 0 ? img.height! : 64;

    final canvas = html.CanvasElement(width: width, height: height);
    final ctx = canvas.context2D;
    ctx
      ..clearRect(0, 0, width.toDouble(), height.toDouble())
      ..drawImageScaled(img, 0, 0, width.toDouble(), height.toDouble());

    final radius = width / 6;
    final centerX = width - radius - 2;
    final centerY = radius + 2;

    ctx
      ..fillStyle = '#ff3b30'
      ..beginPath()
      ..arc(
        centerX.toDouble(),
        centerY.toDouble(),
        radius.toDouble(),
        0,
        2 * math.pi,
      )
      ..closePath()
      ..fill();

    link.href = canvas.toDataUrl('image/png');
  }

  void _restoreOriginal() {
    final link = _findOrCreateFaviconLink();
    final href = _originalHref;
    if (link == null || href == null || href.isEmpty) return;
    link.href = href;
  }
}

