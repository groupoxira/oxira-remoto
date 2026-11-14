// OXIVIEW: botones «Compartir» y «Donar» de la pantalla principal, y «Compartir» de la captura.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common.dart';
import 'package:url_launcher/url_launcher.dart';

const String kOxiraWeb = 'https://remote.oxira.net.pe';
const String kOxiraTexto =
    'OXIVIEW Remote: control remoto gratis para Windows. Descárgalo aquí: $kOxiraWeb/';

Future<void> _abrir(String url) async {
  try {
    if (!await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) {
      showToast('No se pudo abrir el navegador');
    }
  } catch (_) {
    showToast('No se pudo abrir el navegador');
  }
}

/// Fila «Compartir · Donar» debajo de la clave.
Widget oxiraBotonesInicio(BuildContext context) {
  final estilo = TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600));
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        TextButton.icon(
          style: estilo,
          onPressed: oxiraCompartir,
          icon: const Icon(Icons.share, size: 16),
          label: const Text('Compartir'),
        ),
        TextButton.icon(
          style: estilo,
          onPressed: () => _abrir('$kOxiraWeb/donar'),
          icon: const Icon(Icons.favorite, size: 16, color: Color(0xFFE4572E)),
          label: const Text('Donar'),
        ),
      ],
    ),
  );
}

/// Ventana para recomendar el programa (WhatsApp, Facebook, Telegram, copiar enlace).
void oxiraCompartir() {
  final texto = Uri.encodeComponent(kOxiraTexto);
  final web = Uri.encodeComponent('$kOxiraWeb/');
  gFFI.dialogManager.show((setState, close, context) {
    Widget opcion(IconData icono, Color color, String nombre, VoidCallback alTocar) {
      return InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          close();
          alTocar();
        },
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            CircleAvatar(
                radius: 24,
                backgroundColor: color,
                child: Icon(icono, color: Colors.white, size: 24)),
            const SizedBox(height: 6),
            Text(nombre, style: const TextStyle(fontSize: 12)),
          ]),
        ),
      );
    }

    return CustomAlertDialog(
      title: const Text('Compartir'),
      content: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        children: [
          opcion(Icons.chat, const Color(0xFF25D366), 'WhatsApp',
              () => _abrir('https://wa.me/?text=$texto')),
          opcion(Icons.facebook, const Color(0xFF1877F2), 'Facebook',
              () => _abrir('https://www.facebook.com/sharer/sharer.php?u=$web')),
          opcion(Icons.send, const Color(0xFF229ED9), 'Telegram',
              () => _abrir('https://t.me/share/url?url=$web&text=${Uri.encodeComponent('OXIVIEW Remote: control remoto gratis para Windows.')}')),
          opcion(Icons.link, const Color(0xFF00756E), 'Copiar enlace', () {
            Clipboard.setData(const ClipboardData(text: kOxiraTexto));
            showToast('Enlace copiado');
          }),
        ],
      ),
      actions: [dialogButton('Cerrar', onPressed: close, isOutline: true)],
      onCancel: close,
    );
  });
}

/// Captura ya copiada al portapapeles: abre WhatsApp para pegarla.
Future<void> oxiraCompartirFoto() async {
  showToast('Foto copiada. Abre el chat y pulsa Ctrl+V',
      timeout: const Duration(seconds: 6));
  try {
    if (await launchUrl(Uri.parse('whatsapp://'),
        mode: LaunchMode.externalApplication)) {
      return;
    }
  } catch (_) {}
  await _abrir('https://web.whatsapp.com/');
}
