#include <fstream>
#include <iostream>
#include <iomanip>
#include <cstdlib>
#include <string>

#include "sqlite3.h"

using namespace std;


class Lab_7 {
protected:
    // class variables
    string dbName;
    bool isConnected;

	sqlite3* db;
	sqlite3_stmt* stmt_handle;
	const char* stmt_leftover;

public:
    // constructor & destructor
    Lab_7(string& _dbFile) : dbName(_dbFile), isConnected(false) {}
    
    virtual ~Lab_7() {
        if (true == isConnected) {
            CloseConnection();
        }
    }

    // public interface
    void OpenConnection() {
        if (isConnected == false) {
            cout << "++++++++++++++++++++++++++++++++++\n";
            cout << "Open database: " << dbName << endl;

            int rc = sqlite3_open(string(dbName).c_str(), &db);
            if (rc != SQLITE_OK) {
                cout << sqlite3_errmsg(db) << endl;
                sqlite3_close(db);
                exit(1);
            }

            isConnected = true;

            cout << "Successful!\n";
            cout << "++++++++++++++++++++++++++++++++++\n";
        }
    }

    void CloseConnection() {
        if (isConnected == true) {
            cout << "++++++++++++++++++++++++++++++++++\n";
            cout << "Close database: " << dbName << endl;

            sqlite3_close(db);
            isConnected = false;

            cout << "Successful!\n";
            cout << "++++++++++++++++++++++++++++++++++\n";
        }
    }

    void CreateTable() {
        cout << "++++++++++++++++++++++++++++++++++\n";
        cout << "Create table\n";

        // Raw string R"()" literal as type const char* (c_string pointer)
        const char* sqlCreateTable = R"(CREATE TABLE IF NOT EXISTS warehouse (
                                            w_warehousekey DECIMAL(9,0) NOT NULL,
                                            w_name CHAR(100) NOT NULL,
                                            w_capacity DECIMAL(6,0) NOT NULL,
                                            w_suppkey DECIMAL(9,0) NOT NULL,
                                            w_nationkey DECIMAL(2,0) NOT NULL
                                        );
                                    )";

        // Learned from ChatGPT.

        char* errMsg = nullptr;     // Empty pointer for storing the prepared error message (if applicable)
        int result = sqlite3_exec(db, sqlCreateTable, nullptr, nullptr, &errMsg);   // sqlite3_exec wraps the prepare, step, and finalize statements.
                                                                                    // May also execute multiple statements, though not necessary here.
        
        if (result != SQLITE_OK){                   // Check return code to see if it is A-OK.
            cerr << "Error: " << errMsg << endl;    // If not, throw the error and free the memory allocated to it afterwards.
            sqlite3_free(errMsg);
        } else {
            cout << "Successfull!" << endl;         // Otherwise successful.
        }
        cout << "++++++++++++++++++++++++++++++++++\n";
    }

    void PopulateTable() {
        cout << "++++++++++++++++++++++++++++++++++\n";
        cout << "Populate table\n";

        const char* sqlPopulate = R"(
                                    WITH supplier_nation AS (
                                        SELECT
                                            s.s_suppkey                AS s_suppkey,
                                            s.s_name                   AS s_name,
                                            n.n_nationkey              AS n_nationkey,
                                            n.n_name                   AS n_name,
                                            COUNT(*)                   AS lineitems_supplied,
                                            COALESCE(SUM(p.p_size),0)  AS total_partsize
                                        FROM lineitem l
                                        JOIN orders  o ON l.l_orderkey = o.o_orderkey
                                        JOIN customer c ON o.o_custkey   = c.c_custkey
                                        JOIN nation   n ON c.c_nationkey = n.n_nationkey
                                        JOIN part     p ON l.l_partkey   = p.p_partkey
                                        JOIN supplier s ON l.l_suppkey   = s.s_suppkey
                                        GROUP BY s.s_suppkey, n.n_nationkey
                                    ), ranked AS (
                                            SELECT
                                                sn.s_suppkey,
                                                sn.s_name,
                                                sn.n_nationkey,
                                                sn.n_name,
                                                sn.lineitems_supplied,
                                                sn.total_partsize,
                                                ROW_NUMBER() OVER ( PARTITION BY sn.s_suppkey ORDER BY sn.lineitems_supplied DESC, sn.n_name ASC ) AS rn,
                                                MAX(sn.total_partsize) OVER (PARTITION BY sn.s_suppkey) AS max_total_partsize
                                            FROM supplier_nation sn
                                        ),
                                        nums(n) AS (VALUES (1),(2),(3)),
                                        suppliers AS (SELECT s_suppkey, s_name FROM supplier),
                                        top1 AS (SELECT * FROM ranked WHERE rn = 1)
                                        INSERT INTO warehouse (w_warehousekey, w_name, w_capacity, w_suppkey, w_nationkey)
                                        SELECT
                                            ROW_NUMBER() OVER (ORDER BY s.s_suppkey, nums.n)    AS w_warehousekey,
                                            s.s_name || '____' || COALESCE(nct.n_name,'')       AS w_name,
                                            3 * COALESCE(t1.max_total_partsize, 0)              AS w_capacity,
                                            s.s_suppkey                                         AS w_suppkey,
                                            COALESCE(r.n_nationkey, t1.n_nationkey)             AS w_nationkey
                                        FROM suppliers s
                                        CROSS JOIN nums
                                        LEFT JOIN ranked r ON r.s_suppkey = s.s_suppkey AND r.rn = nums.n
                                        LEFT JOIN top1 t1 ON t1.s_suppkey = s.s_suppkey
                                        LEFT JOIN nation nct ON nct.n_nationkey = COALESCE(r.n_nationkey, t1.n_nationkey)
                                        ORDER BY s.s_suppkey, nums.n;
                                    )";

        char* errMsg = nullptr;
        int result = sqlite3_exec(db, sqlPopulate, nullptr, nullptr, &errMsg);
        
        if (result != SQLITE_OK){
            cerr << "Error: " << errMsg << endl;
            sqlite3_free(errMsg);
        } else {
            cout << "Successfull!" << endl;
        }
                
        cout << "++++++++++++++++++++++++++++++++++\n";
    }

    void DropTable() {
        cout << "++++++++++++++++++++++++++++++++++\n";
        cout << "Drop table\n";

        // Stores the return code.
        int rc;

        // Define the SQLite statement as a string.
        string sqlDrop = "DROP TABLE IF EXISTS warehouse;";

        // Prepare the statement and get its return code. Convert string to C string (const char*)
        rc = sqlite3_prepare_v2(db, sqlDrop.c_str(), -1, &stmt_handle, &stmt_leftover);

        if (rc != SQLITE_OK){
            // If the return code is not A-OK, throw error and exit gracefully.
            cout << "Could not compile statement: " << sqlDrop << endl;
            cout << "Error: " << sqlite3_errmsg(db) << endl;
            exit(1);
        }

        rc = sqlite3_step(stmt_handle); // Execute the statement
        if (rc != SQLITE_DONE){
            // If this statement was not finished in one step, then something had gone wrong.
            cout << "Could not compile statement: " << sqlDrop << endl;
            cout << "Error: " << sqlite3_errmsg(db) << endl;
            exit(1);
        } else {
            cout << "Successful!\n";
        }
        sqlite3_finalize(stmt_handle);  // Free resources dedicated to this statement.

        
        cout << "++++++++++++++++++++++++++++++++++\n";
    }

    void Q1() {
        cout << "++++++++++++++++++++++++++++++++++\n";
        cout << "Q1\n";

        int rc;
        const char* query1 = "SELECT w_warehousekey, w_name, w_capacity, w_suppkey, w_nationkey FROM warehouse ORDER BY w_warehousekey;";

        rc = sqlite3_prepare_v2(db, query1, -1, &stmt_handle, &stmt_leftover);
        if (rc != SQLITE_OK) {
            cerr << "Failed to prepare statement: " << sqlite3_errmsg(db) << endl;
            return;
        }

        ofstream out("output/1.out");
        out << left
            << setw(15) << "Warehouse Key "  << "| "
            << setw(42) << "Name"            << "| "
            << setw(10) << "Capcity"         << "| "
            << setw(15) << "Supplier Key "   << "| "
            << setw(10) << "Nation Key"      << "\n";

        out << string(15 + 42 + 10 + 10 + 15 + 10, '-') << "\n";

        // out << setw(10) << left << "Warehouse Key" << " " << setw(40) << left << "Name" << setw(10) << "Capacity"
        //     << setw(10) << "Supplier Key" << setw(10) << "Nation Key" << "\n";

        while (true){
            rc = sqlite3_step(stmt_handle);
            if (rc == SQLITE_DONE) break;
            if (rc != SQLITE_ROW){
                cout << "Could not compile statement: " << query1 << endl;
                cout << "Error: " << sqlite3_errmsg(db) << endl;
                exit(1);
            }

            int wKey = sqlite3_column_int(stmt_handle, 0);
            const unsigned char* wName = sqlite3_column_text(stmt_handle, 1);
            int wCapac = sqlite3_column_int(stmt_handle, 2);
            int w_suppKey = sqlite3_column_int(stmt_handle, 3);
            int w_nationKey = sqlite3_column_int(stmt_handle, 4);

            out << left
                << setw(15) << wKey          << "| "
                << setw(42) << wName         << "| "
                << setw(10) << wCapac        << "| "
                << setw(15) << w_suppKey     << "| "
                << setw(10) << w_nationKey   << "\n";

        }
        sqlite3_finalize(stmt_handle);

        cout << "Successful!\n";

        out.close();
        cout << "++++++++++++++++++++++++++++++++++\n";
    }

    void Q2() {
        cout << "++++++++++++++++++++++++++++++++++\n";
        cout << "Q2\n";

        int rc;
        string query2 = R"(
                            SELECT n_name, COUNT(w_warehousekey) AS numWarehouses, SUM(w_capacity) AS totalCapacity FROM warehouse
                            JOIN nation ON w_nationkey = n_nationkey
                            GROUP BY n_name
                            ORDER BY numWarehouses DESC, totalCapacity DESC, n_name ASC;
                        )";

        rc = sqlite3_prepare_v2(db, query2.c_str(), -1, &stmt_handle, &stmt_leftover);
        if (rc != SQLITE_OK) {
            cerr << "Failed to prepare statement: " << sqlite3_errmsg(db) << endl;
            return;
        }
    
        ofstream out("output/2.out");
        out << left
            << setw(25) << left << "Nation "  << "| "
            << setw(10)         << "numW"     << "| "
            << setw(10)         << "totCap"   << endl;

        out << string(60, '-') << endl;
        // out << setw(40) << left << "nation" << setw(10) << "numW" << setw(10) << "totCap" << "\n";

        while(true){
            rc = sqlite3_step(stmt_handle);
            if (rc == SQLITE_DONE) break;
            if (rc != SQLITE_ROW){
                cout << "Could not compile statement: " << query2 << endl;
                cout << "Error: " << sqlite3_errmsg(db) << endl;
                exit(1);
            }

            const unsigned char* nation = sqlite3_column_text(stmt_handle, 0);
            int numW = sqlite3_column_int(stmt_handle, 1);
            int totCap = sqlite3_column_int(stmt_handle, 2);

            out << left
                << setw(25) << nation << "| "
                << setw(10) << numW   << "| "
                << setw(10) << totCap << "\n";
        }
        sqlite3_finalize(stmt_handle);

        cout << "Successful!" << endl;
    
        out.close();
        cout << "++++++++++++++++++++++++++++++++++\n";
    }

    void Q3() {
        cout << "++++++++++++++++++++++++++++++++++\n";
        cout << "Q3\n";

        ifstream in("input/3.in");
        string nation;
        getline(in, nation);
        in.close();

        int rc;
        string query3 = R"(
                            SELECT DISTINCT s_name, n_name, w_name FROM warehouse
                            JOIN supplier ON w_suppkey = s_suppkey
                            JOIN nation ON w_nationkey = n_nationkey
                            WHERE n_name = ?;
                        )";

        rc = sqlite3_prepare_v2(db, query3.c_str(), -1, &stmt_handle, &stmt_leftover);
        if (rc != SQLITE_OK) {
            cerr << "Failed to prepare statement: " << sqlite3_errmsg(db) << endl;
            return;
        }

        sqlite3_bind_text(stmt_handle, 1, nation.c_str(), nation.length(), 0);  // Tells the program to substitute "?" for a given string, indexed from 1.

        ofstream out("output/3.out");
        out << left
            << setw(20) << left << "Supplier "  << "| "
            << setw(20)         << "Nation"     << "| "
            << setw(40)         << "Warehouse"  << endl;
        out << string(80, '-') << endl;

        while(true){
            rc = sqlite3_step(stmt_handle);
            if (rc == SQLITE_DONE) break;
            if (rc != SQLITE_ROW){
                cout << "Could not compile statement: " << query3 << endl;
                cout << "Error: " << sqlite3_errmsg(db) << endl;
                exit(1);
            }

            const unsigned char* supplierName = sqlite3_column_text(stmt_handle, 0);
            const unsigned char* nationName = sqlite3_column_text(stmt_handle, 1);
            const unsigned char* warehouseName = sqlite3_column_text(stmt_handle, 2);

            out << left
                << setw(20) << supplierName  << "| "
                << setw(20) << nationName    << "| "
                << setw(40) << warehouseName << "\n";
        }
        sqlite3_finalize(stmt_handle);

        cout << "Successful!" << endl;

        out.close();
        cout << "++++++++++++++++++++++++++++++++++\n";
    }

    void Q4() {
        cout << "++++++++++++++++++++++++++++++++++\n";
        cout << "Q4\n";

        ifstream in("input/4.in");
        string region;
        int cap;
        getline(in, region);
        in >> cap;
        in.close();

        int rc;
        string query4 = R"(
                            SELECT w_name, w_capacity FROM warehouse
                            JOIN nation ON w_nationkey = n_nationkey
                            JOIN region ON n_regionkey = r_regionkey
                            WHERE r_name = ? AND w_capacity > ?
                            ORDER BY w_capacity DESC, w_name ASC;
                        )";

        rc = sqlite3_prepare_v2(db, query4.c_str(), -1, &stmt_handle, &stmt_leftover);
        if (rc != SQLITE_OK) {
            cerr << "Failed to prepare statement: " << sqlite3_errmsg(db) << endl;
            return;
        }

        sqlite3_bind_text(stmt_handle, 1, region.c_str(), region.length(), 0);
        sqlite3_bind_int(stmt_handle, 2, cap);

        ofstream out("output/4.out");

        out << left
            << setw(40) << left << "Warehouse "  << "| "
            << setw(10)         << "Capacity"    << endl;
        out << string(50, '-') << endl;

        while(true){
            rc = sqlite3_step(stmt_handle);
            if (rc == SQLITE_DONE) break;
            if (rc != SQLITE_ROW){
                cout << "Could not compile statement: " << query4 << endl;
                cout << "Error: " << sqlite3_errmsg(db) << endl;
                exit(1);
            }

            const unsigned char* warehouseName = sqlite3_column_text(stmt_handle, 0);
            int capacity = sqlite3_column_int(stmt_handle, 1);

            out << left
                << setw(40) << warehouseName  << "| "
                << setw(10) << capacity << "\n";
        }
        sqlite3_finalize(stmt_handle);

        cout << "Successful!" << endl;

        out.close();
        cout << "++++++++++++++++++++++++++++++++++\n";
    }

    void Q5() {
        cout << "++++++++++++++++++++++++++++++++++\n";
        cout << "Q5\n";

        ifstream in("input/5.in");
        string nation;
        getline(in, nation);
        in.close();

        int rc;
        string query5 = R"(
                            SELECT r_name, COALESCE(SUM(w_capacity), 0) FROM region
                            LEFT JOIN nation n_wh ON n_wh.n_regionkey = r_regionkey
                            LEFT JOIN warehouse ON w_nationkey = n_wh.n_nationkey
                            LEFT JOIN supplier ON s_suppkey = w_suppkey
                            LEFT JOIN nation n_sup ON s_nationkey = n_sup.n_nationkey
                                AND n_sup.n_name = ?
                            GROUP BY r_regionkey, r_name
                            ORDER BY r_name ASC;
                        )";

        rc = sqlite3_prepare_v2(db, query5.c_str(), -1, &stmt_handle, &stmt_leftover);
        if (rc != SQLITE_OK) {
            cerr << "Failed to prepare statement: " << sqlite3_errmsg(db) << endl;
            return;
        }

        sqlite3_bind_text(stmt_handle, 1, nation.c_str(), nation.length(), 0);

        ofstream out("output/5.out");

        out << setw(20) << left
            << "Region "        << "| "
            << setw(20) 
            << "Capacity"       << endl;
        out << string(40, '-')  << endl;

        while(true){
            rc = sqlite3_step(stmt_handle);
            if (rc == SQLITE_DONE) break;
            if (rc != SQLITE_ROW){
                cout << "Could not compile statement: " << query5 << endl;
                cout << "Error: " << sqlite3_errmsg(db) << endl;
                exit(1);
            }

            const unsigned char* regionName = sqlite3_column_text(stmt_handle, 0);
            int total_capacity = sqlite3_column_int(stmt_handle, 1);

            out << left
                << setw(20) << regionName       << "| "
                << setw(20) << total_capacity   << "\n";
        }
        sqlite3_finalize(stmt_handle);

        cout << "Successful!" << endl;

        out.close();
        cout << "++++++++++++++++++++++++++++++++++\n";
    }
};


int main (int argc, char* argv[]) {
	if (argc != 2) {
		cout << "Usage: main [sqlite_file]" << endl;
		return -1;
	}

	string dbFile(argv[1]);
	Lab_7 sj(dbFile);
	
	sj.OpenConnection();

    sj.DropTable();
    // sj.CreateTable();
    sj.PopulateTable();
    
    sj.Q1();
    sj.Q2();
    sj.Q3();
    sj.Q4();
    sj.Q5();

    sj.CloseConnection();

	return 0;
}


/*
    Compile with: g++ -g -O0 -Wno-deprecated -o Lab_7.exe Lab_7.cc -lsqlite3
    Install requirements: apt install gcc g++ sqlite3 libsqlite3-dev
*/
