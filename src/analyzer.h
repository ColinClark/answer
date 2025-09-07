#pragma once
#include <QObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>

class Analyzer : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString endpoint READ endpoint WRITE setEndpoint NOTIFY endpointChanged)
    Q_PROPERTY(QString apiKey READ apiKey WRITE setApiKey NOTIFY apiKeyChanged)
    Q_PROPERTY(QString anthropicApiKey READ anthropicApiKey WRITE setAnthropicApiKey NOTIFY anthropicApiKeyChanged)
public:
    explicit Analyzer(QObject* parent=nullptr);

    QString endpoint() const { return m_endpoint; }
    void setEndpoint(const QString& e);
    QString apiKey() const { return m_apiKey; }
    void setApiKey(const QString& k);
    QString anthropicApiKey() const { return m_anthropicApiKey; }
    void setAnthropicApiKey(const QString& k);

    Q_INVOKABLE void initializeSession();
    Q_INVOKABLE void analyzeTextFast(const QString& text);
    Q_INVOKABLE void analyzeTextLLM(const QString& text);
    Q_INVOKABLE void searchStatista(const QStringList& themes);
    Q_INVOKABLE void searchTheme(const QString& theme);
    Q_INVOKABLE void getStatisticById(const QString& id);
    Q_INVOKABLE void executeMCPTool(const QString& toolName, const QJsonObject& params, const QString& requestId);

signals:
    void endpointChanged();
    void apiKeyChanged();
    void anthropicApiKeyChanged();
    void themesReady(const QStringList& themes);
    void resultsReady(const QList<QVariantMap>& items);
    void error(const QString& message);
    void toolResult(const QString& requestId, const QJsonObject& result);

private:
    QStringList extractThemesNaive(const QString& text) const;
    void postJsonRpc(const QJsonObject& payload, std::function<void(const QJsonObject&)> onOk);

    QNetworkAccessManager m_net;
    QString m_endpoint;
    QString m_apiKey;
    QString m_anthropicApiKey;
    QString m_sessionId;
    bool m_sessionInitialized{false};
};