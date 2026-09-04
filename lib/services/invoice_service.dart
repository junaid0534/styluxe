import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

class InvoiceService {
  /// Format a comprehensive, crystal-clear receipt text for WhatsApp & SMS
  static String formatInvoiceText(Map<String, dynamic> order) {
    final rawId = (order['order_id'] ?? order['id'] ?? '00000000').toString();
    final displayId = rawId.length > 8 ? rawId.substring(0, 8).toUpperCase() : rawId.toUpperCase();
    final totalAmt = (order['total_amount'] as num?)?.toDouble() ?? 0.0;
    final status = (order['status']?.toString() ?? 'Pending').toUpperCase();
    final custName = (order['customer_name']?.toString() ?? 'Customer').trim();
    final phone = order['phone']?.toString() ?? 'N/A';
    final address = order['address']?.toString() ?? 'N/A';
    final payMethod = order['payment_method']?.toString() ?? 'Cash on Delivery';
    final courierName = order['courier_name']?.toString();
    final trackingNum = order['tracking_number']?.toString();
    final estDelivery = order['estimated_delivery']?.toString();
    final dateStr = order['created_at'] != null
        ? DateTime.tryParse(order['created_at'].toString())?.toLocal().toString().split('.')[0] ?? ''
        : '';

    final rawItems = order['order_items'] ?? order['items'];
    final List items = (rawItems is List) ? rawItems : [];

    final buffer = StringBuffer();
    buffer.writeln("✨ *STYLUXE OFFICIAL INVOICE* ✨");
    buffer.writeln("━━━━━━━━━━━━━━━━━━━━");
    buffer.writeln("📋 *Order Code:* #STL-$displayId");
    if (dateStr.isNotEmpty) buffer.writeln("📅 *Date:* $dateStr");
    buffer.writeln("🏷️ *Status:* $status");
    buffer.writeln("━━━━━━━━━━━━━━━━━━━━");
    buffer.writeln("👤 *Customer Details:*");
    buffer.writeln("• *Name:* $custName");
    buffer.writeln("• *Phone:* $phone");
    buffer.writeln("• *Address:* $address");

    if (courierName != null && courierName.isNotEmpty) {
      buffer.writeln("━━━━━━━━━━━━━━━━━━━━");
      buffer.writeln("🚚 *Shipping & Courier:*");
      buffer.writeln("• *Courier:* $courierName");
      if (trackingNum != null && trackingNum.isNotEmpty) {
        buffer.writeln("• *Tracking #:* $trackingNum");
      }
      if (estDelivery != null && estDelivery.isNotEmpty) {
        buffer.writeln("• *Est. Delivery:* $estDelivery");
      }
    }

    buffer.writeln("━━━━━━━━━━━━━━━━━━━━");
    buffer.writeln("📦 *Ordered Items (${items.length}):*");

    double calculatedSubtotal = 0.0;
    int idx = 1;
    for (final it in items) {
      if (it is Map) {
        final title = it['product_name']?.toString() ?? (it['products'] is Map ? it['products']['name']?.toString() : null) ?? 'Apparel Item';
        final qty = (it['quantity'] as num?)?.toInt() ?? 1;
        final price = (it['price'] as num?)?.toDouble() ?? 0.0;
        final size = it['size']?.toString() ?? it['selected_size']?.toString();
        final color = it['color']?.toString() ?? it['selected_color']?.toString();
        final itemTotal = price * qty;
        calculatedSubtotal += itemTotal;

        buffer.writeln("$idx. *$title* (x$qty)");
        if (size != null && size.isNotEmpty || color != null && color.isNotEmpty) {
          buffer.writeln("   └ Size: ${size ?? 'Std'} | Color: ${color ?? 'Std'}");
        }
        buffer.writeln("   └ Rs. ${price.toStringAsFixed(0)} x $qty = *Rs. ${itemTotal.toStringAsFixed(0)}*");
        idx++;
      }
    }

    if (calculatedSubtotal <= 0) calculatedSubtotal = totalAmt;
    final shippingFee = totalAmt > calculatedSubtotal ? (totalAmt - calculatedSubtotal) : 0.0;

    buffer.writeln("━━━━━━━━━━━━━━━━━━━━");
    buffer.writeln("💰 *Subtotal:* Rs. ${calculatedSubtotal.toStringAsFixed(0)}");
    if (shippingFee > 0) {
      buffer.writeln("🚚 *Delivery Fee:* Rs. ${shippingFee.toStringAsFixed(0)}");
    }
    buffer.writeln("💵 *Total Payable:* *Rs. ${totalAmt.toStringAsFixed(0)}*");
    buffer.writeln("💳 *Payment:* $payMethod");
    buffer.writeln("━━━━━━━━━━━━━━━━━━━━");
    buffer.writeln("🛍️ *Thank you for choosing StyLuxe Premium!*");
    buffer.writeln("For support or inquiries: contact@styluxe.pk");

    return buffer.toString();
  }

  /// 1-Tap Share to WhatsApp with clear formatted receipt
  static Future<bool> shareViaWhatsApp({
    String? recipientPhone,
    required Map<String, dynamic> order,
  }) async {
    final text = formatInvoiceText(order);
    final encoded = Uri.encodeComponent(text);

    String urlStr;
    if (recipientPhone != null && recipientPhone.trim().isNotEmpty && recipientPhone != 'N/A') {
      final cleanPhone = recipientPhone.replaceAll(RegExp(r'[^0-9]'), '');
      urlStr = "https://wa.me/$cleanPhone?text=$encoded";
    } else {
      urlStr = "https://wa.me/?text=$encoded";
    }

    final uri = Uri.tryParse(urlStr);
    if (uri != null) {
      try {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        debugPrint("Error launching WhatsApp: $e");
      }
    }
    return false;
  }

  /// Copy text invoice to clipboard
  static void copyInvoiceToClipboard(BuildContext context, Map<String, dynamic> order) {
    final text = formatInvoiceText(order);
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Complete invoice details copied to clipboard!"),
        backgroundColor: Color(0xFF2563EB),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Generate, Print & Save PDF Invoice directly to phone storage
  static Future<void> printOrSavePdfInvoice({
    required BuildContext context,
    required Map<String, dynamic> order,
  }) async {
    final rawId = (order['order_id'] ?? order['id'] ?? '00000000').toString();
    final displayId = rawId.length > 8 ? rawId.substring(0, 8).toUpperCase() : rawId.toUpperCase();
    final totalAmt = (order['total_amount'] as num?)?.toDouble() ?? 0.0;
    final status = (order['status']?.toString() ?? 'Pending').toUpperCase();
    final custName = (order['customer_name']?.toString() ?? 'Customer').trim();
    final phone = order['phone']?.toString() ?? 'N/A';
    final address = order['address']?.toString() ?? 'N/A';
    final payMethod = order['payment_method']?.toString() ?? 'Cash on Delivery';
    final courierName = order['courier_name']?.toString() ?? 'StyLuxe Express';
    final trackingNum = order['tracking_number']?.toString() ?? 'STL-$displayId';
    final estDelivery = order['estimated_delivery']?.toString() ?? '2-3 Working Days';
    final dateStr = order['created_at'] != null
        ? DateTime.tryParse(order['created_at'].toString())?.toLocal().toString().split('.')[0] ?? ''
        : '';

    final rawItems = order['order_items'] ?? order['items'];
    final List items = (rawItems is List) ? rawItems : [];

    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        "STYLUXE",
                        style: pw.TextStyle(
                          fontSize: 26,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#2563EB'),
                        ),
                      ),
                      pw.Text(
                        "Official Tax & Order Invoice / Packing Slip",
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        "INVOICE #STL-$displayId",
                        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text("Date: $dateStr", style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                      pw.Text("Status: $status", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#10B981'))),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 16),
              pw.Divider(thickness: 1.5, color: PdfColor.fromHex('#2563EB')),
              pw.SizedBox(height: 12),

              // Customer & Delivery Info
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('#F8FAFC'),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                        border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text("BILLED & SHIPPED TO:", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                          pw.SizedBox(height: 4),
                          pw.Text(custName, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                          pw.Text("Phone: $phone", style: const pw.TextStyle(fontSize: 10)),
                          pw.Text("Address: $address", style: const pw.TextStyle(fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 12),
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('#F8FAFC'),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                        border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text("SHIPPING & LOGISTICS:", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                          pw.SizedBox(height: 4),
                          pw.Text("Courier: $courierName", style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                          pw.Text("Tracking #: $trackingNum", style: const pw.TextStyle(fontSize: 10)),
                          pw.Text("Delivery Window: $estDelivery", style: const pw.TextStyle(fontSize: 10)),
                          pw.Text("Payment Mode: $payMethod", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 18),

              // Items Table
              pw.Text("ORDER ITEMS BREAKDOWN", style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),

              pw.Table(
                border: pw.TableBorder.all(color: PdfColor.fromHex('#CBD5E1'), width: 0.5),
                children: [
                  // Table Header
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColor.fromHex('#EFF6FF')),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("Item Description", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("Size / Color", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("Qty", textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("Unit Price", textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("Total", textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                    ],
                  ),
                  // Table Rows
                  ...items.map((it) {
                    final title = it['product_name']?.toString() ?? (it['products'] is Map ? it['products']['name']?.toString() : null) ?? 'Item';
                    final qty = (it['quantity'] as num?)?.toInt() ?? 1;
                    final price = (it['price'] as num?)?.toDouble() ?? 0.0;
                    final size = it['size']?.toString() ?? it['selected_size']?.toString() ?? '-';
                    final color = it['color']?.toString() ?? it['selected_color']?.toString() ?? '-';

                    return pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(title, style: const pw.TextStyle(fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("$size / $color", style: const pw.TextStyle(fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(qty.toString(), textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("Rs. ${price.toStringAsFixed(0)}", textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text("Rs. ${(price * qty).toStringAsFixed(0)}", textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                      ],
                    );
                  }),
                ],
              ),

              pw.SizedBox(height: 16),

              // Total Summary
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 200,
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#F8FAFC'),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                      border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text("Payment:", style: const pw.TextStyle(fontSize: 9)),
                            pw.Text(payMethod, style: const pw.TextStyle(fontSize: 9)),
                          ],
                        ),
                        pw.SizedBox(height: 4),
                        pw.Divider(thickness: 0.5, color: PdfColors.grey400),
                        pw.SizedBox(height: 4),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text("Total Payable:", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                            pw.Text("Rs. ${totalAmt.toStringAsFixed(0)}", style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#2563EB'))),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              pw.Spacer(),

              // Footer Note
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Divider(thickness: 0.5, color: PdfColors.grey400),
                    pw.SizedBox(height: 4),
                    pw.Text("StyLuxe Premium Apparel • www.styluxe.pk • support@styluxe.pk", style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                    pw.Text("Computer generated invoice - no physical signature required.", style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'StyLuxe_Invoice_$displayId.pdf',
    );
  }
}
