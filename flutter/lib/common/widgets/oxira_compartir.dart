// OXIVIEW: botones «Compartir» y «Donar» de la pantalla principal, y «Compartir» de la captura.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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

/// «Compartir · Donar» y «Ayúdanos a mejorar» debajo de la clave.
Widget oxiraBotonesInicio(BuildContext context) {
  final estilo = TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600));
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
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
        TextButton.icon(
          style: estilo,
          onPressed: oxiraComentario,
          icon: const Icon(Icons.lightbulb_outline, size: 16),
          label: const Text('Ayúdanos a mejorar'),
        ),
      ],
    ),
  );
}

/// «Ayúdanos a mejorar»: la persona escribe una idea o una falla y llega a nuestro servidor.
void oxiraComentario() {
  final texto = TextEditingController();
  final contacto = TextEditingController();
  String tipo = 'idea';
  bool enviando = false;
  String? error;
  gFFI.dialogManager.show((setState, close, context) {
    Future<void> enviar() async {
      if (texto.text.trim().isEmpty) {
        setState(() => error = 'Escribe tu comentario.');
        return;
      }
      setState(() {
        enviando = true;
        error = null;
      });
      try {
        final r = await http
            .post(Uri.parse('$kOxiraWeb/api/comentarios'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({
                  'id': gFFI.serverModel.serverId.text.replaceAll(' ', ''),
                  'ver': version,
                  'os': '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
                  'tipo': tipo,
                  'texto': texto.text.trim(),
                  'contacto': contacto.text.trim(),
                }))
            .timeout(const Duration(seconds: 15));
        if (r.statusCode == 200) {
          close();
          showToast('¡Gracias! Lo leemos todo.');
          return;
        }
        String msg = 'No se pudo enviar (${r.statusCode}). Reintenta.';
        try {
          final d = jsonDecode(r.body);
          if (d is Map && d['mensaje'] is String) msg = d['mensaje'];
        } catch (_) {}
        setState(() {
          enviando = false;
          error = msg;
        });
      } catch (_) {
        setState(() {
          enviando = false;
          error = 'Sin conexión con el servidor. Revisa tu internet y reintenta.';
        });
      }
    }

    Widget chip(String valor, String nombre) => ChoiceChip(
          label: Text(nombre),
          selected: tipo == valor,
          onSelected: enviando ? null : (_) => setState(() => tipo = valor),
        );

    return CustomAlertDialog(
      title: const Text('Ayúdanos a mejorar'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(spacing: 8, children: [
              chip('idea', 'Idea'),
              chip('falla', 'Algo falla'),
              chip('otro', 'Otro'),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: texto,
              enabled: !enviando,
              autofocus: true,
              minLines: 4,
              maxLines: 8,
              maxLength: 3000,
              decoration: const InputDecoration(
                  hintText: '¿Qué mejorarías? ¿Qué falló?',
                  border: OutlineInputBorder()),
            ),
            TextField(
              controller: contacto,
              enabled: !enviando,
              decoration: const InputDecoration(
                  hintText: 'WhatsApp o correo (opcional, para responderte)',
                  border: OutlineInputBorder()),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(error!, style: const TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
      actions: [
        dialogButton('Cancelar', onPressed: enviando ? null : close, isOutline: true),
        dialogButton(enviando ? 'Enviando…' : (error != null ? 'Reintentar' : 'Enviar'),
            onPressed: enviando ? null : enviar),
      ],
      onCancel: enviando ? null : close,
    );
  });
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
