/* Haplo Platform                                     http://haplo.org
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


#ifndef OXPCONTROLLER__H
#define OXPCONTROLLER__H

#include <map>

class OXPController {
public:
    OXPController();
    ~OXPController();
private:
    OXPController(const OXPController &);   // no copying
public:

    // Return the singleton controller
    static OXPController &GetController() { return msController; }

    // oxp_* postgres functions
    void PgResetAll();
    void PgReset();
    void PgOpen(unsigned int Slot, const char *Pathname);
    void PgSimpleQuery(unsigned int Slot, const char *Query, const char *Prefix, std::vector<int> &rResultsOut);
    void PgDisableRelevancy();
    int PgGetRelevancy(unsigned int Docid);
    std::string PgSpelling(unsigned int Slot, const char *Word);

    // Implementation stuff
    void ImplSimpleQuery(Xapian::Database &db, const char *Query, const char *Prefix, std::vector<int> &rResultsOut);

    // Handy functions
    Xapian::Database &GetDatabase(unsigned int Slot);
    void CloseLeastRecentlyUsedDatabase();
    void CloseAllDatabases();

    // Tracking class
    class OpenDatabase {
    public:
        OpenDatabase(std::string &rPathname);
        ~OpenDatabase();
    private:
        OpenDatabase(const OpenDatabase &); // no copying
    public:
        void Open();
        Xapian::Database &GetXapianDatabase();

        // Serial number tracking
        void UpdateOpenSerial(int s) { mOpenSerial = s; }
        int GetOpenSerial() const { return mOpenSerial; }

    private:
        Xapian::Database *mpDatabase;
        std::string mDatabasePathname;
        int mOpenSerial;
    };
    typedef std::map<std::string,OpenDatabase*> OXPOpenDatabaseMap;
    typedef std::vector<OpenDatabase*> OXPDatabaseSlots;

private:
    static OXPController msController;

    int mOpenSerial;    // increment a number when a database was last opened

    OXPOpenDatabaseMap mOpenDatabases;
    OXPDatabaseSlots mDatabaseSlots;

    bool mRelevancyEnabled;
    // TODO: Use hash_map if it's easy?
    typedef std::map<int, int> OXPRelevancyMap;
    OXPRelevancyMap mRelevancy;
};

#endif // OXPCONTROLLER__H

