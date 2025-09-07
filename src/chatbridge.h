#pragma once
#include <QObject>
#include <QVariantList>
#include <QNetworkAccessManager>
#include <QNetworkReply>

// Streaming ChatBridge: supports incremental tokens, citations with "open in new tab",
// and a queue of follow-up queries.
class ChatBridge : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString endpoint READ endpoint WRITE setEndpoint NOTIFY endpointChanged)
    Q_PROPERTY(QString apiKey READ apiKey WRITE setApiKey NOTIFY apiKeyChanged)
    Q_PROPERTY(QString anthropicApiKey READ anthropicApiKey WRITE setAnthropicApiKey NOTIFY anthropicApiKeyChanged)
    Q_PROPERTY(QVariantList messages READ messages NOTIFY messagesChanged)
    Q_PROPERTY(QVariantList followups READ followups NOTIFY followupsChanged)

public:
    explicit ChatBridge(QObject* parent=nullptr);

    QString endpoint() const { return m_endpoint; }
    void setEndpoint(const QString& e);
    QString apiKey() const { return m_apiKey; }
    void setApiKey(const QString& k);
    QString anthropicApiKey() const { return m_anthropicApiKey; }
    void setAnthropicApiKey(const QString& k);

    QVariantList messages() const { return m_messages; }
    QVariantList followups() const { return m_followups; }

    Q_INVOKABLE void initializeSession();
    Q_INVOKABLE void reset();
    Q_INVOKABLE void sendMessage(const QString& userText, const QVariantMap& context);
    Q_INVOKABLE void sendThemeQuery(const QString& theme);
    Q_INVOKABLE void runFollowupQueue(const QVariantMap& context);
    Q_INVOKABLE void setAnalyzer(QObject* analyzer);

signals:
    void endpointChanged();
    void apiKeyChanged();
    void anthropicApiKeyChanged();
    void messagesChanged();
    void followupsChanged();
    void error(const QString& msg);
    void partialUpdated(); // emitted when the last assistant message receives new tokens
    void streamingFinished(); // emitted when streaming is complete
    void citationsUpdated(const QList<QVariantMap>& cites); // emitted when citations are updated

private slots:
    void onToolResult(const QString& requestId, const QJsonObject& result);

private:
    void append(const QString& role, const QString& text);
    void updateLastAssistant(const QString& delta);
    void addCitations(const QList<QVariantMap>& cites);
    void setFollowups(const QList<QVariantMap>& fups);
    void postStream(const QJsonObject& payload);
    void sendToClaudeAPI(const QString& userText, const QVariantMap& context);
    void processClaudeStream();
    void executeToolCall(const QString& toolName, const QString& toolId, const QString& toolInput);
    void callStatistaMCP(const QString& method, const QJsonObject& params, const QString& toolId);
    void sendToolResult(const QString& toolId, const QJsonObject& result);
    void postToClaudeAPI(const QJsonObject& payload);

    QNetworkAccessManager m_net;
    QString m_endpoint;
    QString m_apiKey;
    QString m_anthropicApiKey;
    QString m_sessionId;
    bool m_sessionInitialized{false};

    QVariantList m_messages;
    QVariantList m_followups;
    QList<QVariantMap> m_currentCitations;
    QByteArray m_buffer;
    QNetworkReply* m_reply{nullptr};
    
    // Tool use tracking
    QString m_currentToolName;
    QString m_currentToolId;
    QString m_currentToolInput;
    
    // Store tool call details by tool ID for later use in sendToolResult
    struct ToolCallDetails {
        QString name;
        QString input;
    };
    QHash<QString, ToolCallDetails> m_toolCallDetails;
    
    // Analyzer reference for MCP calls
    QObject* m_analyzer{nullptr};
    QHash<QString, bool> m_pendingToolCalls;
};