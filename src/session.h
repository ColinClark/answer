#pragma once
#include <QObject>
#include <QStringList>
#include <QSettings>

class Session : public QObject {
    Q_OBJECT
public:
    explicit Session(QObject* parent=nullptr) : QObject(parent) {}

    Q_INVOKABLE QStringList loadTabs() const {
        QSettings s;
        int size = s.beginReadArray("tabs");
        QStringList urls;
        for (int i=0;i<size;++i) {
            s.setArrayIndex(i);
            urls << s.value("url").toString();
        }
        s.endArray();
        if (urls.isEmpty()) {
            urls << "https://example.com";
        }
        return urls;
    }

    Q_INVOKABLE int loadActiveIndex() const {
        QSettings s;
        return s.value("activeIndex", 0).toInt();
    }

    Q_INVOKABLE void saveTabs(const QStringList& urls, int activeIndex) {
        QSettings s;
        s.beginWriteArray("tabs");
        for (int i=0;i<urls.size();++i) {
            s.setArrayIndex(i);
            s.setValue("url", urls.at(i));
        }
        s.endArray();
        s.setValue("activeIndex", activeIndex);
        s.sync();
    }
};