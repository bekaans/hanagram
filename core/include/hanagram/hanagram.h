/*
 * Hanagram — çekirdek genel arayüzü (C ABI)
 *
 * Bu dosya, çekirdek ile dış dünya arasındaki TEK sözleşmedir.
 * Sunum katmanı (Flutter/Dart, Swift, Kotlin, C#) yalnızca buraya bakar;
 * çekirdeğin iç sınıflarına erişimi yoktur.
 *
 * Neden C (C++ değil): C ABI derleyiciden ve dilden bağımsız olarak kararlıdır.
 * dart:ffi, JNI, P/Invoke ve Swift doğrudan bağlanabilir.
 *
 * İş parçacığı: hg_call farklı iş parçacıklarından çağrılabilir; çekirdek kendi
 * içinde kilitler. hg_start/hg_stop tek iş parçacığından çağrılmalıdır.
 *
 * Bellek: dönen char* çağıran tarafa aittir ve hg_free ile serbest bırakılmalıdır.
 */
#ifndef HANAGRAM_H
#define HANAGRAM_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#if defined(_WIN32)
#  if defined(HANAGRAM_BUILD_SHARED)
#    define HG_API __declspec(dllexport)
#  elif defined(HANAGRAM_USE_SHARED)
#    define HG_API __declspec(dllimport)
#  else
#    define HG_API
#  endif
#else
#  define HG_API __attribute__((visibility("default")))
#endif

/* Sözleşme sürümü. Kırıcı değişiklikte MAJOR artar; uygulama açılışta kontrol eder. */
#define HANAGRAM_ABI_MAJOR 1
#define HANAGRAM_ABI_MINOR 0

typedef struct hg_runtime hg_runtime;

/*
 * Çekirdeği başlat.
 *   data_dir : verinin yazılacağı dizin. NULL veya "" ise yalnızca bellekte çalışır.
 *   config   : JSON yapılandırma; NULL olabilir.
 * Dönüş: tutamaç, ya da başarısızlıkta NULL.
 */
HG_API hg_runtime* hg_start(const char* data_dir, const char* config_json);

/* Çekirdeği durdur; bekleyen veriyi diske yazar. NULL güvenlidir. */
HG_API void hg_stop(hg_runtime* rt);

/*
 * Tek giriş noktası. Tüm işlevsellik buradan geçer.
 *   method  : "feed.get", "invite.redeem", "admin.users" ...
 *   payload : JSON nesnesi (NULL = boş nesne)
 * Dönüş: JSON sonuç. Sözleşme:
 *   başarı → {"ok":true,"data":{...}}
 *   hata   → {"ok":false,"code":"ERR_...","hint":"..."}
 * Dönen dizge hg_free ile serbest bırakılmalıdır. Asla NULL dönmez.
 */
HG_API char* hg_call(hg_runtime* rt, const char* method, const char* payload_json);

/*
 * Olay aboneliği: çekirdek → uygulama bildirimleri.
 * Geri çağırma ÇEKİRDEĞİN iş parçacığından çalışır; içinde uzun iş yapma.
 * topic ve payload yalnızca çağrı süresince geçerlidir; saklanacaksa kopyalanmalı.
 */
typedef void (*hg_event_cb)(const char* topic, const char* payload_json, void* user_data);
HG_API uint64_t hg_subscribe(hg_runtime* rt, hg_event_cb cb, void* user_data);
HG_API void hg_unsubscribe(hg_runtime* rt, uint64_t subscription);

/* hg_call'dan dönen belleği serbest bırak. */
HG_API void hg_free(char* s);

/* Çekirdek sürümü, ör. "1.0.0". Statik dizge; serbest bırakılmaz. */
HG_API const char* hg_version(void);

/* ABI sürümü — uygulama uyumluluğu kontrol eder. */
HG_API int hg_abi_major(void);
HG_API int hg_abi_minor(void);

#ifdef __cplusplus
}
#endif

#endif /* HANAGRAM_H */
