/*
 * Copyright 2019 Chris Clime
 *
 * This file is part of morph-browser.
 *
 * morph-browser is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 3.
 *
 * morph-browser is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#include "domain-settings-model.h"
#include "domain-utils.h"

#include <QFile>
#include <QtSql/QSqlQuery>
#include <QUrl>

#define CONNECTION_NAME "morph-browser-domainsettings"

namespace
{
  const double ZoomFactorCompareThreshold = 0.01;
}

/*!
    \class DomainSettingsModel
    \brief model that stores domain specific settings.
*/
DomainSettingsModel::DomainSettingsModel(QObject* parent)
: QAbstractListModel(parent)
{
    m_database = QSqlDatabase::addDatabase(QLatin1String("QSQLITE"), CONNECTION_NAME);
    m_defaultZoomFactor = 1.0;
}

DomainSettingsModel::~DomainSettingsModel()
{
    m_database.close();
    m_database = QSqlDatabase();
    QSqlDatabase::removeDatabase(CONNECTION_NAME);
}

void DomainSettingsModel::resetDatabase(const QString& databaseName)
{
    beginResetModel();
    m_entries.clear();
    m_database.close();
    m_database.setDatabaseName(databaseName);
    m_database.open();
    createOrAlterDatabaseSchema();
    removeDefaultZoomFactorFromEntries();
    removeObsoleteEntries();
    endResetModel();
    populateFromDatabase();
    Q_EMIT rowCountChanged();
}

QHash<int, QByteArray> DomainSettingsModel::roleNames() const
{
    static QHash<int, QByteArray> roles;
    if (roles.isEmpty()) {
        roles[Domain] = "domain";
        roles[DomainWithoutSubdomain] = "domainWithoutSubdomain";
        roles[AllowCustomUrlSchemes] = "allowCustomUrlSchemes";
        roles[AllowLocation] = "allowLocation";
        roles[UserAgentId] = "userAgentId";
        roles[ZoomFactor] = "zoomFactor";
    }
    return roles;
}

int DomainSettingsModel::rowCount(const QModelIndex& parent) const
{
    Q_UNUSED(parent);
    return m_entries.count();
}

QVariant DomainSettingsModel::data(const QModelIndex& index, int role) const
{
    if (!index.isValid()) {
        return QVariant();
    }
    const DomainSetting& entry = m_entries.at(index.row());
    switch (role) {
    case Domain:
        return entry.domain;
    case DomainWithoutSubdomain:
        return entry.domainWithoutSubdomain;
    case AllowCustomUrlSchemes:
        return entry.allowCustomUrlSchemes;
    case AllowLocation:
        return entry.allowLocation;
    case UserAgentId:
        return entry.userAgentId;
    case ZoomFactor:
        return entry.zoomFactor;
    default:
        return QVariant();
    }
}

void DomainSettingsModel::createOrAlterDatabaseSchema()
{
    QSqlQuery createQuery(m_database);
    QString query = QLatin1String("CREATE TABLE IF NOT EXISTS domainsettings "
                                  "(domain VARCHAR NOT NULL UNIQUE, domainWithoutSubdomain VARCHAR, allowCustomUrlSchemes BOOL, allowLocation BOOL, "
                                  "userAgentId INTEGER, zoomFactor REAL, PRIMARY KEY(domain), FOREIGN KEY(userAgentId) REFERENCES useragents(id)); ");
    createQuery.prepare(query);
    createQuery.exec();
}

void DomainSettingsModel::populateFromDatabase()
{
    QSqlQuery populateQuery(m_database);
    QString query = QLatin1String("SELECT domain, domainWithoutSubdomain, allowCustomUrlSchemes, allowLocation, userAgentId, zoomFactor "
                                  "FROM domainsettings;");
    populateQuery.prepare(query);
    populateQuery.exec();
    int count = 0; // size() isn't supported on the sqlite backend
    while (populateQuery.next()) {
        DomainSetting entry;
        entry.domain = populateQuery.value("domain").toString();
        entry.domainWithoutSubdomain = populateQuery.value("domainWithoutSubdomain").toString();
        entry.allowCustomUrlSchemes = populateQuery.value("allowCustomUrlSchemes").toBool();
        entry.allowLocation = populateQuery.value("allowLocation").toBool();
        entry.userAgentId = populateQuery.value("userAgentId").toInt();
        entry.zoomFactor =  populateQuery.value("zoomFactor").isNull() ? std::numeric_limits<double>::quiet_NaN()
                                                                       : populateQuery.value("zoomFactor").toDouble();

        beginInsertRows(QModelIndex(), count, count);
        m_entries.append(entry);
        endInsertRows();
        count++;
    }
}

const QString DomainSettingsModel::databasePath() const
{
    return m_database.databaseName();
}

void DomainSettingsModel::setDatabasePath(const QString& path)
{
    if (path != databasePath()) {
        if (path.isEmpty()) {
            resetDatabase(":memory:");
        } else {
            resetDatabase(path);
        }
        Q_EMIT databasePathChanged();
    }
}

double DomainSettingsModel::defaultZoomFactor() const
{
    return m_defaultZoomFactor;
}

void DomainSettingsModel::setDefaultZoomFactor(double defaultZoomFactor)
{
    m_defaultZoomFactor = defaultZoomFactor;
}

bool DomainSettingsModel::contains(const QString& domain) const
{
    return (getIndexForDomain(domain) >= 0);
}

void DomainSettingsModel::deleteAndResetDataBase()
{
    if (QFile::exists(databasePath()))
    {
        QFile(databasePath()).remove();
    }
    resetDatabase(databasePath());
}

bool DomainSettingsModel::areCustomUrlSchemesAllowed(const QString& domain)
{
    int index = getIndexForDomain(domain);
    if (index == -1)
    {
        return false;
    }

    return m_entries[index].allowCustomUrlSchemes;
}

void DomainSettingsModel::allowCustomUrlSchemes(const QString& domain, bool allow)
{
    insertEntry(domain);

    int index = getIndexForDomain(domain);
    if (index != -1) {
        DomainSetting& entry = m_entries[index];
        if (entry.allowCustomUrlSchemes == allow) {
            return;
        }
        entry.allowCustomUrlSchemes = allow;
        Q_EMIT dataChanged(this->index(index, 0), this->index(index, 0), QVector<int>() << AllowCustomUrlSchemes);
        QSqlQuery query(m_database);
        static QString updateStatement = QLatin1String("UPDATE domainsettings SET allowCustomUrlSchemes=? WHERE domain=?;");
        query.prepare(updateStatement);
        query.addBindValue(allow);
        query.addBindValue(domain);
        query.exec();
    }
}

bool DomainSettingsModel::isLocationAllowed(const QString& domain) const
{
    int index = getIndexForDomain(domain);
    if (index == -1)
    {
        return false;
    }

    return m_entries[index].allowLocation;
}

void DomainSettingsModel::allowLocation(const QString& domain, bool allow)
{
    insertEntry(domain);

    int index = getIndexForDomain(domain);
    if (index != -1) {
        DomainSetting& entry = m_entries[index];
        if (entry.allowLocation == allow) {
            return;
        }
        entry.allowLocation = allow;
        Q_EMIT dataChanged(this->index(index, 0), this->index(index, 0), QVector<int>() << AllowLocation);
        QSqlQuery query(m_database);
        static QString updateStatement = QLatin1String("UPDATE domainsettings SET allowLocation=? WHERE domain=?;");
        query.prepare(updateStatement);
        query.addBindValue(allow);
        query.addBindValue(domain);
        query.exec();
    }
}

int DomainSettingsModel::getUserAgentId(const QString& domain) const
{
    int index = getIndexForDomain(domain);
    if (index == -1)
    {
        return std::numeric_limits<int>::quiet_NaN();
    }

    return m_entries[index].userAgentId;
}

void DomainSettingsModel::setUserAgentId(const QString& domain, int userAgentId)
{
    insertEntry(domain);

    int index = getIndexForDomain(domain);
    if (index != -1) {
        DomainSetting& entry = m_entries[index];
        if (entry.userAgentId == userAgentId) {
            return;
        }
        entry.userAgentId = userAgentId;
        Q_EMIT dataChanged(this->index(index, 0), this->index(index, 0), QVector<int>() << UserAgentId);
        QSqlQuery query(m_database);
        static QString updateStatement = QLatin1String("UPDATE domainsettings SET userAgentId=? WHERE domain=?;");
        query.prepare(updateStatement);
        query.addBindValue((userAgentId > 0) ? userAgentId : QVariant());
        query.addBindValue(domain);
        query.exec();
    }
}

void DomainSettingsModel::removeUserAgentIdFromAllDomains(int userAgentId)
{
    bool foundDomainWithGivenUserAgentId = false;
    for (int i = 0; i < m_entries.length(); i++)
    {
        if (m_entries[i].userAgentId == userAgentId) {
            foundDomainWithGivenUserAgentId = true;
            m_entries[i].userAgentId = 0;
            Q_EMIT dataChanged(this->index(i, 0), this->index(i, 0), QVector<int>() << UserAgentId);
        }
    }

    if (foundDomainWithGivenUserAgentId)
    {
        QSqlQuery query(m_database);
        static QString updateStatement = QLatin1String("UPDATE domainsettings SET userAgentId=NULL WHERE userAgentId=?;");
        query.prepare(updateStatement);
        query.addBindValue(userAgentId);
        query.exec();
    }
}

double DomainSettingsModel::getZoomFactor(const QString& domain) const
{
    int index = getIndexForDomain(domain);
    if (index == -1)
    {
        return std::numeric_limits<double>::quiet_NaN();
    }

    return m_entries[index].zoomFactor;
}

void DomainSettingsModel::setZoomFactor(const QString& domain, double zoomFactor)
{
    // if zoomFactor matches the default zoom factor, insert NULL instead
    double newZoomFactor = (std::abs(zoomFactor - m_defaultZoomFactor) < ZoomFactorCompareThreshold) ? std::numeric_limits<double>::quiet_NaN()
                                                                                                     : zoomFactor;

    insertEntry(domain);

    int index = getIndexForDomain(domain);
    if (index != -1) {
        DomainSetting& entry = m_entries[index];
        if (std::abs(entry.zoomFactor - newZoomFactor) < ZoomFactorCompareThreshold) {
            return;
        }
        entry.zoomFactor = newZoomFactor;
        Q_EMIT dataChanged(this->index(index, 0), this->index(index, 0), QVector<int>() << ZoomFactor);
        QSqlQuery query(m_database);
        static QString updateStatement = QLatin1String("UPDATE domainsettings SET zoomFactor=? WHERE domain=?;");
        query.prepare(updateStatement);
        query.addBindValue(newZoomFactor);
        query.addBindValue(domain);
        query.exec();
    }
}

void DomainSettingsModel::insertEntry(const QString &domain)
{
    if (contains(domain))
    {
        return;
    }

    beginInsertRows(QModelIndex(), 0, 0);
    DomainSetting entry;
    entry.domain = domain;
    entry.domainWithoutSubdomain = DomainUtils::getDomainWithoutSubdomain(domain);
    entry.allowCustomUrlSchemes = false;
    entry.allowLocation = false;
    entry.userAgentId = 0;
    entry.zoomFactor = std::numeric_limits<double>::quiet_NaN();
    m_entries.append(entry);
    endInsertRows();
    Q_EMIT rowCountChanged();

    QSqlQuery query(m_database);
    static QString insertStatement = QLatin1String("INSERT INTO domainsettings (domain, domainWithoutSubdomain, allowCustomUrlSchemes, allowLocation, userAgentId, zoomFactor)"
                                                   " VALUES (?, ?, ?, ?, ?, ?);");
    query.prepare(insertStatement);
    query.addBindValue(entry.domain);
    query.addBindValue(entry.domainWithoutSubdomain);
    query.addBindValue(entry.allowCustomUrlSchemes);
    query.addBindValue(entry.allowLocation);
    query.addBindValue((entry.userAgentId > 0) ? entry.userAgentId : QVariant());
    query.addBindValue(entry.zoomFactor);
    query.exec();
}

void DomainSettingsModel::removeEntry(const QString &domain)
{
    int index = getIndexForDomain(domain);
    if (index != -1) {
        beginRemoveRows(QModelIndex(), index, index);
        m_entries.removeAt(index);
        endRemoveRows();
        Q_EMIT rowCountChanged();
        QSqlQuery query(m_database);
        static QString deleteStatement = QLatin1String("DELETE FROM domainsettings WHERE domain=?;");
        query.prepare(deleteStatement);
        query.addBindValue(domain);
        query.exec();
    }
}

void DomainSettingsModel::removeObsoleteEntries()
{
    QSqlQuery query(m_database);
    static QString deleteStatement = QLatin1String("DELETE FROM domainsettings WHERE allowCustomUrlSchemes=? AND allowLocation=? AND userAgentId IS NULL AND zoomFactor IS NULL;");
    query.prepare(deleteStatement);
    query.addBindValue(false);
    query.addBindValue(false);
    query.exec();
}

void DomainSettingsModel::removeDefaultZoomFactorFromEntries()
{
    QSqlQuery query(m_database);
    static QString updateStatement = QLatin1String("UPDATE domainsettings SET zoomFactor=? WHERE ABS(zoomFactor-?) < ?");
    query.prepare(updateStatement);
    query.addBindValue(std::numeric_limits<double>::quiet_NaN());
    query.addBindValue(m_defaultZoomFactor);
    query.addBindValue(ZoomFactorCompareThreshold);
    query.exec();
}

int DomainSettingsModel::getIndexForDomain(const QString& domain) const
{
    int index = 0;
    foreach(const DomainSetting& entry, m_entries) {
        if (entry.domain == domain) {
            return index;
        } else {
            ++index;
        }
    }
    return -1;
}
