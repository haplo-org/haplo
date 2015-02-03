/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


#include "xapian.h"
#include <stdexcept>
#include <algorithm>
#include <unistd.h>

#include "KXapianWriter.h"

// A bit longer than the term length limit in the java convert server, to allow for some UTF-8 chars
// TODO: Handle truncating over-long terms on UTF-8 boundaries in a consistent manner throughout
#define MAX_TERM_LENGTH_UTF8        176

// The unstemmed word prefix
#define UNSTEMMED_WORD_PREFIX       "_"

// ---------------------------------------------------------------------------------------------------------------------
//    Writer handles
// ---------------------------------------------------------------------------------------------------------------------

int KXapianWriter::msHandleBase = -1;
std::vector<KXapianWriter*> KXapianWriter::msWriters;

int KXapianWriter::OpenHandle(const std::string &rFullDatabasePathname, const std::string &rFieldsDatabasePathname) {
    // Assign a vaguely unpredictable base for handles? This makes sure that code which assumes 'slots' as per the
    // reading interface will fail.
    if(msHandleBase == -1) {
        msHandleBase = ((int)::getpid()) & 0xffff;
    }

    KXapianWriter *pwriter = new KXapianWriter();
    if(pwriter == 0) { throw std::runtime_error("Failed to create writer"); }

    int index = -1;
    for(unsigned int i = 0; i < msWriters.size(); ++i) {
        if(msWriters[i] == 0) {
            index = i;
            msWriters[i] = pwriter;
        }
    }

    // No empty slot? Will need to allocate one.
    if(index == -1) {
        index = msWriters.size();
        msWriters.push_back(pwriter);
    }

    // Open the Xapian databases, and clean up if there's an error
    try {
        pwriter->Open(rFullDatabasePathname, rFieldsDatabasePathname);
    }
    catch(...) {
        msWriters[index] = 0;
        delete pwriter;
        throw;
    }

    return index + msHandleBase;
}

KXapianWriter &KXapianWriter::FromHandle(int Handle) {
    int index = Handle - msHandleBase;
    if(index < 0 || index >= ((int)msWriters.size()) || msWriters[index] == 0) {
        throw std::runtime_error("Bad writer handle");
    }

    return *(msWriters[index]);
}

void KXapianWriter::CloseHandle(int Handle) {
    KXapianWriter &writer(FromHandle(Handle));
    writer.Close();
    msWriters[Handle - msHandleBase] = 0;
    delete &writer;
}


// ---------------------------------------------------------------------------------------------------------------------
//    Writer implementation
// ---------------------------------------------------------------------------------------------------------------------

int KXapianWriter::msNextOpenSerial = 0;

KXapianWriter::KXapianWriter()
    : mpFullDatabase(0), mpFieldsDatabase(0), mpFullDoc(0), mpFieldsDoc(0), mOpenSerial(0) {
}

KXapianWriter::~KXapianWriter() {
    Close();
}

void KXapianWriter::Open(const std::string &rFullDatabasePathname, const std::string &rFieldsDatabasePathname) {
    if(IsOpen()) {
        throw std::runtime_error("Already open");
    }

    // Open both databases, and clean up on exceptions
    try {
        mpFullDatabase = new Xapian::WritableDatabase(rFullDatabasePathname, Xapian::DB_OPEN);
        mpFieldsDatabase = new Xapian::WritableDatabase(rFieldsDatabasePathname, Xapian::DB_OPEN);
    }
    catch(...) {
        Close();
        throw;
    }

    // Store an open serial number so last used databases can be easily identified
    mOpenSerial = msNextOpenSerial++;
}

void KXapianWriter::Close() {
    // DOCUMENTS
    DeleteDocs();

    // DATABASES
    if(mpFullDatabase != 0) {
        delete mpFullDatabase;
        mpFullDatabase = 0;
    }
    if(mpFieldsDatabase != 0) {
        delete mpFieldsDatabase;
        mpFieldsDatabase = 0;
    }
}

void KXapianWriter::DeleteDocs() {
    if(mpFullDoc != 0) {
        delete mpFullDoc;
        mpFullDoc = 0;
    }
    if(mpFieldsDoc != 0) {
        delete mpFieldsDoc;
        mpFieldsDoc = 0;
    }
}


void KXapianWriter::CheckIsOpen() {
    if(!IsOpen()) {
        throw std::runtime_error("Not open");
    }
}

void KXapianWriter::StartTransaction() {
    CheckIsOpen();
    DeleteDocs();
    mpFullDatabase->begin_transaction();
    mpFieldsDatabase->begin_transaction();
}

void KXapianWriter::StartDocument() {
    CheckIsOpen();
    DeleteDocs();
    try {
        mpFullDoc = new Xapian::Document();
        mpFieldsDoc = new Xapian::Document();
    }
    catch(...) {
        DeleteDocs();
        throw;
    }
}

// Terms is a UTF-8 encoded string
int KXapianWriter::PostTerms(const char *Terms, const char *Prefix1, const char *Prefix2, int TermPositionStart, int Weight) {
    CheckIsOpen();
    if(mpFullDoc == 0 || mpFieldsDoc == 0) {
        throw std::runtime_error("Haven't started a document before calling post terms");
    }
    if(Terms == 0) {
        throw std::runtime_error("No terms passed");
    }

    int termPosition = TermPositionStart;

    // Make a string containing the unstemmed word prefix -- don't want to create lots of temporary strings
    std::string unstemmedWordPrefix(UNSTEMMED_WORD_PREFIX);

    // Setup prefix
    std::string p1, p1_us, p2, p2_us;
    if(Prefix1 != 0) { p1 = Prefix1; p1_us = p1 + unstemmedWordPrefix; }
    if(Prefix2 != 0) { p2 = Prefix2; p2_us = p2 + unstemmedWordPrefix; }

    // Run through terms in string
    int p = 0; // current position
    int s = 0; // current term start
    int m = -1; // current word / stemmed term separator
    while(true) {
        // End of term?
        // Cast to unsigned char because non-7bit chars encoded with UTF-8 result in bytes with 8th bit set, ie negative signed chars.
        if(((unsigned char)Terms[p]) <= ' ') {
            if(s < p && m != -1) {
                // Got a word + term combination
                // NOTE: Truncate to MAX_TERM_LENGTH_UTF8 (which does unfortunately ignore UTF-8 boundaries)
                std::string word(Terms + s, std::min(m - s, MAX_TERM_LENGTH_UTF8));
                bool haveWord = (word.length() > 0);
                std::string term(Terms + m + 1, std::min(p - (m + 1), MAX_TERM_LENGTH_UTF8));
                bool haveTerm = (term.length() > 0);

                // Add to documents
                if(haveWord) { mpFullDoc->add_posting(unstemmedWordPrefix + word, termPosition, Weight); }
                if(haveTerm) { mpFullDoc->add_posting(term, termPosition, Weight); }
                if(Prefix1 != 0) {
                    if(haveWord) { mpFieldsDoc->add_posting(p1_us + word, termPosition, Weight); }
                    if(haveTerm) { mpFieldsDoc->add_posting(p1 + term, termPosition, Weight); }
                }
                if(Prefix2 != 0) {
                    if(haveWord) { mpFieldsDoc->add_posting(p2_us + word, termPosition, Weight); }
                    if(haveTerm) { mpFieldsDoc->add_posting(p2 + term, termPosition, Weight); }
                }

                // Add spelling to database for spelling suggestions in searches.
                // Note that this is not strictly correct: edits will increment the frequency count, and deletes don't remove words.
                mpFullDatabase->add_spelling(word);

                ++termPosition;
            }

            // Next term (may) start at the character after this one
            s = p + 1;

            // Clear separator position
            m = -1;
        }

        // Separator?
        if(Terms[p] == ':') {
            m = p;
        }

        if(Terms[p] == '\0') {
            break;
        }

        // Next character
        ++p;
    }

    return termPosition;
}

void KXapianWriter::FinishDocument(int DocID) {
    CheckIsOpen();
    if(mpFullDoc == 0 || mpFieldsDoc == 0) {
        throw std::runtime_error("Haven't started a document before calling finish document");
    }

    // Xapian only allows document IDs > 0, but Q_NULL has ID 0. Special case to not save the
    // document for Q_NULL, as we don't need to index it.
    if(DocID > 0) {
        mpFullDatabase->replace_document(DocID, *mpFullDoc);
        mpFieldsDatabase->replace_document(DocID, *mpFieldsDoc);
    }

    DeleteDocs();
}

void KXapianWriter::DeleteDocument(int DocID) {
    CheckIsOpen();
    mpFullDatabase->delete_document(DocID);
    mpFieldsDatabase->delete_document(DocID);
}

void KXapianWriter::CancelTransaction() {
    CheckIsOpen();
    DeleteDocs();
    mpFullDatabase->cancel_transaction();
    mpFieldsDatabase->cancel_transaction();
}

void KXapianWriter::CommitTransaction() {
    CheckIsOpen();
    DeleteDocs();
    mpFullDatabase->commit_transaction();
    mpFieldsDatabase->commit_transaction();
}



