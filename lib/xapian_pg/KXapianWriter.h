/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


#ifndef KXAPIAN_WRITER__H
#define KXAPIAN_WRITER__H

#include <vector>

class KXapianWriter {
public:
    KXapianWriter();
    ~KXapianWriter();
private:
    KXapianWriter(const KXapianWriter &);   // no copying
public:

    // Creation, returning a handle.
    static int OpenHandle(const std::string &rFullDatabasePathname, const std::string &rFieldsDatabasePathname);
    // Get a writer, given a handle. Will exception if it's an invalid handle.
    static KXapianWriter &FromHandle(int Handle);
    // Close a writer, given a handle. Will exception if it's an invalid handle.
    static void CloseHandle(int Handle);

public:
    void Open(const std::string &rFullDatabasePathname, const std::string &rFieldsDatabasePathname);
    void Close();
    void StartTransaction();
    void StartDocument();
    int  PostTerms(const char *Terms, const char *Prefix1, const char *Prefix2, int TermPositionStart, int Weight);
    void FinishDocument(int DocID);
    void DeleteDocument(int DocID);
    void CancelTransaction();
    void CommitTransaction();

    int GetOpenSerial() const { return mOpenSerial; }

    bool IsOpen() const { return mpFullDatabase != 0 && mpFieldsDatabase != 0; }

private:
    void CheckIsOpen();
    void DeleteDocs();

private:
    Xapian::WritableDatabase *mpFullDatabase;
    Xapian::WritableDatabase *mpFieldsDatabase;
    Xapian::Document *mpFullDoc;
    Xapian::Document *mpFieldsDoc;
    int mOpenSerial;

    static int msNextOpenSerial;

    static int msHandleBase;
    static std::vector<KXapianWriter*> msWriters;
};

#endif // KXAPIAN_WRITER__H

