import 'dart:io';
import 'dart:math';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'format_converter.dart';

/// 图片 → PDF 转换器
///
/// 支持单图和多图两种场景：
/// - 单图：一张图片占一页，居中适配
/// - 多图紧凑排列：2×2 网格，每页最多 4 张
/// - 多图一图一页：每张图片独立一页
class ImagePdfConverter {
  ImagePdfConverter._();

  /// 单图 → PDF
  static Future<ConvertResult> convertSingle(
    String imagePath,
    String outputPath,
  ) async {
    return convertMultiple(
      [imagePath],
      outputPath,
      mode: ImagePdfMode.onePerPage,
    );
  }

  /// 多图 → PDF
  ///
  /// [mode] 排版模式：
  /// - [ImagePdfMode.onePerPage]：一图一页
  /// - [ImagePdfMode.compact]：紧凑排列（2×2 网格，每页 4 张）
  static Future<ConvertResult> convertMultiple(
    List<String> imagePaths,
    String outputPath, {
    ImagePdfMode mode = ImagePdfMode.onePerPage,
  }) async {
    try {
      final document = pw.Document();
      final images = <pw.MemoryImage>[];

      for (final path in imagePaths) {
        final file = File(path);
        if (!await file.exists()) continue;
        final bytes = await file.readAsBytes();
        images.add(pw.MemoryImage(bytes));
      }

      if (images.isEmpty) {
        return ConvertResult.fail('没有可用的图片');
      }

      switch (mode) {
        case ImagePdfMode.onePerPage:
          for (final img in images) {
            document.addPage(
              pw.Page(
                pageFormat: PdfPageFormat.a4,
                margin: const pw.EdgeInsets.all(40),
                build: (context) => pw.Align(
                  alignment: pw.Alignment.topCenter,
                  child: pw.Image(img, fit: pw.BoxFit.contain),
                ),
              ),
            );
          }
          break;

        case ImagePdfMode.compact:
          const columns = 2;
          const rowsPerPage = 2;
          const imagesPerPage = columns * rowsPerPage;

          final pageWidth = PdfPageFormat.a4.width - 80;
          final pageHeight = PdfPageFormat.a4.height - 80;
          final cellWidth = pageWidth / columns;
          final cellHeight = pageHeight / rowsPerPage;

          for (var i = 0; i < images.length; i += imagesPerPage) {
            final pageImages = images.sublist(
              i,
              min(i + imagesPerPage, images.length),
            );

            document.addPage(
              pw.Page(
                pageFormat: PdfPageFormat.a4,
                margin: const pw.EdgeInsets.all(40),
                build: (context) {
                  final rows = <pw.TableRow>[];
                  for (var r = 0; r < rowsPerPage; r++) {
                    final cells = <pw.Widget>[];
                    for (var c = 0; c < columns; c++) {
                      final idx = r * columns + c;
                      if (idx < pageImages.length) {
                        cells.add(
                          pw.Container(
                            width: cellWidth,
                            height: cellHeight,
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Image(
                              pageImages[idx],
                              fit: pw.BoxFit.contain,
                            ),
                          ),
                        );
                      } else {
                        cells.add(pw.Container());
                      }
                    }
                    rows.add(pw.TableRow(children: cells));
                  }
                  return pw.Table(children: rows);
                },
              ),
            );
          }
          break;
      }

      final outFile = File(outputPath);
      await outFile.writeAsBytes(await document.save());
      return ConvertResult.ok(outputPath);
    } catch (e) {
      return ConvertResult.fail('图片 → PDF 转换失败: $e');
    }
  }
}

enum ImagePdfMode {
  onePerPage,
  compact,
}
