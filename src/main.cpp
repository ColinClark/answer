#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QtWebEngineQuick/QtWebEngineQuick>
#include <QQmlContext>
#include "session.h"
#include "analyzer.h"
#include "chatbridge.h"
#include "config.h"

using namespace Qt::StringLiterals;

int main(int argc, char *argv[]) {
    // High-DPI scaling is enabled by default in Qt6

    QGuiApplication app(argc, argv);
    QCoreApplication::setOrganizationName("MicroCo");
    QCoreApplication::setOrganizationDomain("micro.example");
    QCoreApplication::setApplicationName("MicroBrowser");

    QtWebEngineQuick::initialize();

    Session session;
    Analyzer analyzer;
    ChatBridge chat;

    // Use configuration with embedded defaults (falls back to env vars if set)
    analyzer.setEndpoint(Config::getStatistaMcpEndpoint());
    analyzer.setApiKey(Config::getStatistaMcpApiKey());
    analyzer.setAnthropicApiKey(Config::getAnthropicApiKey());
    chat.setEndpoint(Config::getStatistaMcpEndpoint());
    chat.setApiKey(Config::getStatistaMcpApiKey());
    chat.setAnthropicApiKey(Config::getAnthropicApiKey());
    
    // Connect ChatBridge to Analyzer for MCP calls
    chat.setAnalyzer(&analyzer);

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("session", &session);
    engine.rootContext()->setContextProperty("analyzer", &analyzer);
    engine.rootContext()->setContextProperty("chat", &chat);

    const QUrl url(u"qrc:/MicroBrowser/qml/Main.qml"_s);
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated, &app,
                     [url](QObject *obj, const QUrl &objUrl) {
                         if (!obj && url == objUrl)
                             QCoreApplication::exit(-1);
                     }, Qt::QueuedConnection);
    engine.load(url);

    return app.exec();
}