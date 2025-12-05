#include <fstream>
#include <iostream>
#include <iomanip>
#include <cstdlib>
#include <string>

#include "sqlite3.h"

using namespace std;

class aims {
protected:
    string database;
    bool connected;
    
    sqlite3* db;
    sqlite3_stmt* stmt_handle;
    const char* stmt_leftover;

public:
    aims(string& _dbFile) : database(_dbFile), connected(false){}

    void openConnection() {
        if (!connected) {
            cout << "----------------------------------" << endl;
            cout << "Open database: " << database << endl;

            int rc = sqlite3_open(string(database).c_str(), &db);
            if (rc != SQLITE_OK) {
                cout << sqlite3_errmsg(db) << endl;
                sqlite3_close(db);
                exit(1);
            }

            connected = true;

            cout << "Successful!" << endl;;
            cout << "----------------------------------" << std::endl;
        }
    }

    void closeConnection(){
        if (connected){
            cout << "----------------------------------" << endl;
            cout << "Close database: " << database << endl;

            sqlite3_close(db);
            connected = false;

            cout << "Successful!" << endl;
            cout << "----------------------------------" << endl;
        }
    }

    virtual ~aims(){
        if (connected) connected = false;
    }
};

int main(int argc, char* argv[]){
    if (argc != 2) {
        cout << "Usage: main [sqlite (database) file.]" << endl;
        return -1;
    }

    string dbFile = argv[1];
    aims dbConn(dbFile);
    dbConn.openConnection();

    while(true){

        string userInput;
        cin >> userInput;

        if(userInput == "exit"){
            break;
        }

    }

    dbConn.closeConnection();
    return 0;
}