import 'transport.dart';

/// Web [Transport] stub.
///
/// `package:http`'s `BrowserClient` uses XHR and **buffers the entire response
/// body** before completing `send` — fatal for an infinite SSE stream — so web
/// cannot reuse this package's `http.Client` path. The real web transport
/// (`package:web` `fetch` + `ReadableStream`, with `AbortController`
/// cancellation, Gap G-1) lands in **Story 4.10**; until then web throws.
Transport createTransport() =>
    throw UnsupportedError('koel_http web transport lands in Story 4.10');
