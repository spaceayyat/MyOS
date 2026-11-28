// PIP's understanding and safety rules. VYLO_NETWORK_TEST=1 adds one real
// download over HTTPS.
#include <QFile>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QTest>

#include "downloader.h"
#include "pipbrain.h"

class PipTest : public QObject
{
    Q_OBJECT
private slots:
    void understands_data()
    {
        QTest::addColumn<QString>("input");
        QTest::addColumn<QString>("action");
        QTest::addColumn<QString>("text");
        QTest::addColumn<int>("number");
        auto row = [](const char *input, const char *action, const char *text = "", int number = 0) {
            QTest::newRow(input) << QString::fromUtf8(input) << QString::fromLatin1(action)
                                 << QString::fromLatin1(text) << number;
        };
        row("help", "help");
        row("Hey PIP, can you open Files please?", "open", "Files");
        row("go to github.com", "open", "github.com");
        row("search moon phases", "search", "moon phases");
        row("download https://example.org/a.iso", "download", "https://example.org/a.iso");
        row("install gimp", "install", "gimp");
        row("volume 40%", "volume", "", 40);
        row("volume 900", "volume", "", 100);
        row("unmute", "mute", "unmute");
        row("dark mode", "theme", "dark");
        row("accent lilac", "accent", "lilac");
        row("next wallpaper", "wallpaper");
        row("quiet mode", "mode", "quiet");
        row("remind me in 10 minutes to stretch", "remind", "stretch", 600);
        row("timer 90 s", "remind", "", 90);
        row("remind me in 900 hours", "unknown", "remind me in 900 hours");
        row("shut down", "power", "poweroff");
        row("restart", "power", "reboot");
        row("bye", "quit");
        row("what is 12*7?", "calc", "12*7");
        row("2 + 2", "calc", "2 + 2");
        row("screenshot", "screenshot");
        row("open downloads", "folder", "downloads");
        row("note buy tea", "note", "buy tea");
        row("notes", "notes");
        row("clear my notes", "clearnotes");
        row("reminders", "reminders");
        row("cancel all reminders", "cancelreminders");
        row("flip a coin", "coin");
        row("roll a die", "dice");
        row("rm -rf /", "unknown", "rm -rf /");
        row("   ", "empty");
    }
    void understands()
    {
        QFETCH(QString, input);
        QFETCH(QString, action);
        QFETCH(QString, text);
        QFETCH(int, number);
        const Pip::Intent intent = Pip::parse(input);
        QCOMPARE(intent.action, action);
        QCOMPARE(intent.text, text);
        QCOMPARE(intent.number, number);
    }

    void calculator()
    {
        QCOMPARE(Pip::calculate("2+3*4"), QStringLiteral("14"));
        QCOMPARE(Pip::calculate(" (2+3) x 4 "), QStringLiteral("20"));
        QCOMPARE(Pip::calculate("-6/4"), QStringLiteral("-1.5"));
        for (const char *bad : {"1/0", "5%0", "2+", "(1", "1 2", "system(1)", ""})
            QVERIFY2(Pip::calculate(QString::fromLatin1(bad)).isEmpty(), bad);
        QVERIFY(Pip::calculate(QString(5000, '(') + "1").isEmpty());
    }

    void webAddresses()
    {
        QCOMPARE(Pip::webAddress("github.com/x").toString(), QStringLiteral("https://github.com/x"));
        QVERIFY(Pip::webAddress("http://example.org").isValid());
        for (const char *bad : {"files", "file:///etc/passwd", "javascript:alert(1)",
                                "https://user:pw@example.org/", "two words.com now"})
            QVERIFY2(!Pip::webAddress(QString::fromLatin1(bad)).isValid(), bad);
    }

    void downloadsAreHttpsOnly()
    {
        QVERIFY(Pip::safeDownload(QUrl("https://example.org/a")));
        QVERIFY(!Pip::safeDownload(QUrl("http://example.org/a")));
        QVERIFY(!Pip::safeDownload(QUrl("file:///etc/passwd")));
        QTemporaryDir dir;
        Downloader downloader;
        QVERIFY(!downloader.start(QUrl("http://example.org/a"), dir.path()));
    }

    void fileNamesStayInTheFolder()
    {
        QCOMPARE(Pip::safeFileName(QUrl("https://x.org/a/b.zip?x=1")), QStringLiteral("b.zip"));
        QCOMPARE(Pip::safeFileName(QUrl("https://x.org/..%2F..%2F.bashrc")), QStringLiteral("bashrc"));
        QCOMPARE(Pip::safeFileName(QUrl("https://x.org/.profile")), QStringLiteral("profile"));
        QCOMPARE(Pip::safeFileName(QUrl("https://x.org/")), QStringLiteral("download"));
        QVERIFY(Pip::safeFileName(QUrl("https://x.org/" + QString(400, 'a'))).size() <= 120);
    }

    void existingFilesAreKept()
    {
        QTemporaryDir dir;
        QFile file(dir.filePath("a.txt"));
        QVERIFY(file.open(QIODevice::WriteOnly));
        QCOMPARE(Pip::freePath(dir.path(), "a.txt"), dir.filePath("a (1).txt"));
    }

    void realDownload()
    {
        if (!qEnvironmentVariableIsSet("VYLO_NETWORK_TEST"))
            QSKIP("set VYLO_NETWORK_TEST=1 to download over the network");
        QTemporaryDir dir;
        Downloader downloader;
        QSignalSpy done(&downloader, &Downloader::finished);
        QVERIFY(downloader.start(QUrl("https://raw.githubusercontent.com/spaceayyat/MyOS/main/LICENSE"), dir.path()));
        QVERIFY(done.wait(40000));
        QVERIFY2(done.first().at(0).toBool(), qPrintable(done.first().at(1).toString()));
        QFile saved(dir.filePath("LICENSE"));
        QVERIFY(saved.open(QIODevice::ReadOnly));
        QVERIFY(saved.readAll().contains("MIT"));
        QVERIFY(!(saved.permissions() & QFile::ExeOwner));
    }
};

QTEST_GUILESS_MAIN(PipTest)
#include "test_pip.moc"
