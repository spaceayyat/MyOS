#pragma once

#include <QNetworkAccessManager>
#include <QObject>
#include <QSaveFile>
#include <QUrl>
#include <memory>

class QNetworkReply;

// Saves one HTTPS download at a time into a folder. Never opens or runs the
// file; certificate errors end the download.
class Downloader : public QObject
{
    Q_OBJECT
public:
    explicit Downloader(QObject *parent = nullptr);

    bool busy() const { return m_reply != nullptr; }
    bool start(const QUrl &url, const QString &folder);
    void cancel();

signals:
    void progress(int percent); // -1 if the size is unknown
    void finished(bool ok, const QString &message);

private:
    void done(bool ok, const QString &message);

    QNetworkAccessManager m_network;
    QNetworkReply *m_reply = nullptr;
    std::unique_ptr<QSaveFile> m_file;
};
