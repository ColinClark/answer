#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QtWebEngineQuick/QtWebEngineQuick>
#include <QQmlContext>
#include "session.h"
#include "analyzer.h"
#include "chatbridge.h"

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

    analyzer.setEndpoint(qEnvironmentVariable("STATISTA_MCP_ENDPOINT", "https://api.statista.ai/v1/mcp"));
    analyzer.setApiKey(qEnvironmentVariable("STATISTA_MCP_API_KEY"));
    analyzer.setAnthropicApiKey(qEnvironmentVariable("ANTHROPIC_API_KEY"));
    chat.setEndpoint(qEnvironmentVariable("STATISTA_MCP_ENDPOINT", "https://api.statista.ai/v1/mcp"));
    chat.setApiKey(qEnvironmentVariable("STATISTA_MCP_API_KEY"));
    chat.setAnthropicApiKey(qEnvironmentVariable("ANTHROPIC_API_KEY"));
    
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