package com.nasirabbas.luckygames

import android.graphics.Bitmap
import android.net.http.SslError
import android.os.Message
import android.view.KeyEvent
import android.webkit.*

/** Adds subframe scheme handling while preserving Flutter's WebView callbacks. */
class FrameNavigationClient(
    private val delegate: WebViewClient,
    private val onSubframeNavigation: (WebResourceRequest) -> Boolean?,
) : WebViewClient() {
    override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
        if (!request.isForMainFrame) {
            onSubframeNavigation(request)?.let { return it }
        }
        // Ordinary iframe URLs are never manually loadUrl'ed into the main frame.
        return delegate.shouldOverrideUrlLoading(view, request)
    }

    @Deprecated("Legacy WebView callback")
    override fun shouldOverrideUrlLoading(view: WebView, url: String) =
        delegate.shouldOverrideUrlLoading(view, url)

    override fun onPageStarted(view: WebView, url: String, favicon: Bitmap?) =
        delegate.onPageStarted(view, url, favicon)
    override fun onPageFinished(view: WebView, url: String) = delegate.onPageFinished(view, url)
    override fun onLoadResource(view: WebView, url: String) = delegate.onLoadResource(view, url)
    override fun onPageCommitVisible(view: WebView, url: String) = delegate.onPageCommitVisible(view, url)
    override fun doUpdateVisitedHistory(view: WebView, url: String, isReload: Boolean) =
        delegate.doUpdateVisitedHistory(view, url, isReload)
    override fun onReceivedError(view: WebView, request: WebResourceRequest, error: WebResourceError) =
        delegate.onReceivedError(view, request, error)
    @Deprecated("Legacy WebView callback")
    override fun onReceivedError(view: WebView, code: Int, description: String, url: String) =
        delegate.onReceivedError(view, code, description, url)
    override fun onReceivedHttpError(view: WebView, request: WebResourceRequest, response: WebResourceResponse) =
        delegate.onReceivedHttpError(view, request, response)
    override fun onReceivedSslError(view: WebView, handler: SslErrorHandler, error: SslError) =
        delegate.onReceivedSslError(view, handler, error)
    override fun onReceivedHttpAuthRequest(view: WebView, handler: HttpAuthHandler, host: String, realm: String) =
        delegate.onReceivedHttpAuthRequest(view, handler, host, realm)
    override fun onReceivedClientCertRequest(view: WebView, request: ClientCertRequest) =
        delegate.onReceivedClientCertRequest(view, request)
    override fun onFormResubmission(view: WebView, dontResend: Message, resend: Message) =
        delegate.onFormResubmission(view, dontResend, resend)
    override fun onReceivedLoginRequest(view: WebView, realm: String, account: String?, args: String) =
        delegate.onReceivedLoginRequest(view, realm, account, args)
    override fun onScaleChanged(view: WebView, oldScale: Float, newScale: Float) =
        delegate.onScaleChanged(view, oldScale, newScale)
    override fun onUnhandledKeyEvent(view: WebView, event: KeyEvent) = delegate.onUnhandledKeyEvent(view, event)
    override fun shouldOverrideKeyEvent(view: WebView, event: KeyEvent) = delegate.shouldOverrideKeyEvent(view, event)
    override fun shouldInterceptRequest(view: WebView, request: WebResourceRequest): WebResourceResponse? =
        delegate.shouldInterceptRequest(view, request)
    @Deprecated("Legacy WebView callback")
    override fun shouldInterceptRequest(view: WebView, url: String): WebResourceResponse? =
        delegate.shouldInterceptRequest(view, url)
    override fun onRenderProcessGone(view: WebView, detail: RenderProcessGoneDetail) =
        delegate.onRenderProcessGone(view, detail)
    override fun onSafeBrowsingHit(view: WebView, request: WebResourceRequest, threatType: Int, response: SafeBrowsingResponse) =
        delegate.onSafeBrowsingHit(view, request, threatType, response)
}
