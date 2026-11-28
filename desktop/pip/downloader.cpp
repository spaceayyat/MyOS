#include "downloader.h"

#include <QDir>
#include <QNetworkReply>
#include <QNetworkRequest>

#include "pipbrain.h"

Downloader::Downloader(QObject *parent)
    : QObject(parent)
{
}

bool Downloader::start(const QUrl &url, const QString &folder)
{
    if (busy() || !Pip::safeDownload(url) || !QDir().mkpath(folder))
        return false;
    // QSaveFile writes to a temporary file, so a failed download leaves nothing.
    m_file = std::make_unique<QSaveFile>(Pip::freePath(folder, Pip::safeFileName(url)));
    if (!m_file->open(QIODevice::WriteOnly)) {
        m_file.reset();
        return false;
    }
    QNetworkRequest request(url);
    // Redirects are followed, but never from https to http.
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                         QNetworkRequest::NoLessSafeRedirectPolicy);
    request.setTransferTimeout(30000);
    m_reply = m_network.get(request);

    connect(m_reply, &QNetworkReply::readyRead, this, [this] {
        if (m_file && m_file->write(m_reply->readAll()) < 0)
            m_reply->abort(); // disk full or similar
    });
    connect(m_reply, &QNetworkReply::downloadProgress, this, [this](qint64 got, qint64 total) {
        emit progress(total > 0 ? int(got * 100 / total) : -1);
    });
    connect(m_reply, &QNetworkReply::finished, this, [this] {
        if (m_reply->error() != QNetworkReply::NoError) {
            done(false, m_reply->errorString());
            return;
        }
        const int status = m_reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        if (status != 200) {
            done(false, QStringLiteral("The server answered %1.").arg(status));
            return;
        }
        m_file->write(m_reply->readAll());
        const QString path = m_file->fileName();
        if (!m_file->commit()) {
            done(false, m_file->errorString());
            return;
        }
        done(true, path);
    });
    return true;
}

void Downloader::cancel()
{
    if (m_reply)
        m_reply->abort();
}

void Downloader::done(bool ok, const QString &message)
{
    m_reply->deleteLater();
    m_reply = nullptr;
    m_file.reset(); // discards an uncommitted file
    emit finished(ok, message);
}
