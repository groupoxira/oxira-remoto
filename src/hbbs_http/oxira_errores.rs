// OXIVIEW: sube a nuestro servidor las líneas ERROR (y PANIC) nuevas de los logs, como mucho cada 6 h.
// Solo el texto del error, su origen (archivo:línea) y cuántas veces pasó: nunca pantalla ni archivos.
// Este módulo no escribe log::error! para no alimentarse a sí mismo.
use hbb_common::{
    config::{Config, LocalConfig},
    log,
    tokio::{self, time::Instant},
};
use serde_json::json;
use std::{
    collections::HashMap,
    io::{Read, Seek, SeekFrom},
    path::PathBuf,
    sync::Mutex,
    time::{Duration, SystemTime},
};

const CLAVE: &str = "oxira-errores-hasta";
const CADA: Duration = Duration::from_secs(6 * 3600);
const MAX_LEER: u64 = 512 * 1024;
const MAX_ERRORES: usize = 100;
const MAX_MSG: usize = 2000;
const DIAS: u64 = 7;
const LARGO_FECHA: usize = 27; // "[2026-11-14 10:00:00.123456"

lazy_static::lazy_static! {
    static ref ULTIMO: Mutex<Option<Instant>> = Mutex::new(None);
}

/// Deja los PANIC en el log (como ERROR) para que también se suban.
pub fn gancho_panico() {
    let anterior = std::panic::take_hook();
    std::panic::set_hook(Box::new(move |info| {
        log::error!("PANIC {}", info);
        anterior(info);
    }));
}

fn carpetas() -> Vec<PathBuf> {
    let mut v = vec![Config::log_path()];
    #[cfg(windows)]
    {
        // El servicio corre como SYSTEM; los logs de la ventana están en el perfil de cada usuario.
        let app = hbb_common::config::APP_NAME.read().unwrap().clone();
        if let Ok(rd) = std::fs::read_dir("C:\\Users") {
            for u in rd.flatten() {
                let p = u.path().join("AppData").join("Roaming").join(&app).join("log");
                if p.is_dir() && !v.contains(&p) {
                    v.push(p);
                }
            }
        }
    }
    v
}

fn archivos() -> Vec<PathBuf> {
    let limite = SystemTime::now() - Duration::from_secs(DIAS * 86400);
    let mut out = vec![];
    let mut pendientes: Vec<(PathBuf, u8)> = carpetas().into_iter().map(|p| (p, 0)).collect();
    while let Some((dir, nivel)) = pendientes.pop() {
        let Ok(rd) = std::fs::read_dir(&dir) else { continue };
        for e in rd.flatten() {
            let p = e.path();
            let Ok(md) = e.metadata() else { continue };
            if md.is_dir() {
                if nivel < 2 {
                    pendientes.push((p, nivel + 1));
                }
            } else if p.extension().map(|x| x == "log").unwrap_or(false)
                && md.modified().map(|m| m >= limite).unwrap_or(false)
            {
                out.push(p);
            }
        }
    }
    out
}

fn leer_cola(p: &PathBuf) -> String {
    let Ok(mut f) = std::fs::File::open(p) else { return String::new() };
    let largo = f.metadata().map(|m| m.len()).unwrap_or(0);
    if largo > MAX_LEER {
        f.seek(SeekFrom::Start(largo - MAX_LEER)).ok();
    }
    let mut buf = vec![];
    f.read_to_end(&mut buf).ok();
    String::from_utf8_lossy(&buf).into_owned()
}

/// Devuelve [(origen, mensaje, veces)] posteriores a `hasta` y la fecha más nueva vista.
fn recoger(hasta: String) -> (Vec<(String, String, usize)>, String) {
    let mut grupos: HashMap<(String, String), usize> = HashMap::new();
    let mut maximo = hasta.clone();
    for p in archivos() {
        for linea in leer_cola(&p).lines() {
            let Some(fecha) = linea.get(0..LARGO_FECHA) else { continue };
            if !fecha.starts_with('[') || fecha <= hasta.as_str() {
                continue;
            }
            let Some(i) = linea.find("] ERROR [") else { continue };
            let resto = &linea[i + 9..];
            let (origen, msg) = match resto.find("] ") {
                Some(j) => (&resto[..j], &resto[j + 2..]),
                None => ("", resto),
            };
            let msg: String = msg.chars().take(MAX_MSG).collect();
            *grupos.entry((origen.to_owned(), msg)).or_insert(0) += 1;
            if fecha > maximo.as_str() {
                maximo = fecha.to_owned();
            }
        }
    }
    let mut lista: Vec<(String, String, usize)> =
        grupos.into_iter().map(|((o, m), n)| (o, m, n)).collect();
    lista.sort_by(|a, b| b.2.cmp(&a.2));
    lista.truncate(MAX_ERRORES);
    (lista, maximo)
}

/// `api` = dirección del servidor sin barra final (ej. https://remote.oxira.net.pe).
pub async fn subir_si_toca(api: String) {
    {
        let mut u = ULTIMO.lock().unwrap();
        if u.map(|x| x.elapsed() < CADA).unwrap_or(false) {
            return;
        }
        *u = Some(Instant::now());
    }
    let hasta = LocalConfig::get_option(CLAVE);
    let (lista, maximo) = tokio::task::spawn_blocking(move || recoger(hasta))
        .await
        .unwrap_or_default();
    if lista.is_empty() {
        return;
    }
    let errores: Vec<_> = lista
        .iter()
        .map(|(o, m, n)| json!({"o": o, "m": m, "n": n}))
        .collect();
    let cuerpo = json!({
        "id": Config::get_id(),
        "uuid": crate::encode64(hbb_common::get_uuid()),
        "ver": crate::VERSION,
        "os": crate::get_sysinfo()["os"],
        "errores": errores,
    });
    match crate::post_request(format!("{}/api/errores", api), cuerpo.to_string(), "").await {
        Ok(_) => LocalConfig::set_option(CLAVE.to_owned(), maximo),
        Err(e) => log::warn!("no se pudo subir el informe de errores: {e:?}"),
    }
}
