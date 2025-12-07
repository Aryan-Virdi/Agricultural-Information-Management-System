// aims_cli.cpp
// Build: g++ -std=c++17 aims_cli.cpp -o aims_cli -lsqlite3
// Run: ./aims_cli /path/to/aims.sqlite

#include <sqlite3.h>
#include <iostream>
#include <string>
#include <vector>
#include <cstdio>
#include <cctype>
#include <sstream>
#include <regex>
#include <iomanip>
#include <memory>

using std::string;
using std::cout;
using std::cin;
using std::endl;
using std::vector;

// ---------- Helpers ----------
bool file_exists(const string &path) {
    FILE *f = fopen(path.c_str(), "rb");
    if (!f) return false;
    fclose(f);
    return true;
}

bool valid_date(const string &d) {
    // Simple YYYY-MM-DD format check (not fully validating days/months/leap years)
    std::regex re(R"(^\d{4}-\d{2}-\d{2}$)");
    return std::regex_match(d, re);
}

bool is_non_negative_double(const string &s) {
    try {
        double v = std::stod(s);
        return v >= 0.0;
    } catch (...) { return false; }
}

void print_row(sqlite3_stmt* stmt) {
    int cols = sqlite3_column_count(stmt);
    for (int i = 0; i < cols; ++i) {
        const char* name = sqlite3_column_name(stmt, i);
        const char* text = (const char*)sqlite3_column_text(stmt, i);
        if (!text) cout << name << ": NULL";
        else cout << name << ": " << text;
        if (i < cols-1) cout << " | ";
    }
    cout << "\n";
}

void print_table_header(sqlite3_stmt* stmt) {
    int cols = sqlite3_column_count(stmt);
    for (int i = 0; i < cols; ++i) {
        cout << std::left << std::setw(18) << sqlite3_column_name(stmt, i);
    }
    cout << "\n";
    for (int i = 0; i < cols; ++i) cout << std::setw(18) << std::string(18, '-');
    cout << "\n";
}

static int print_generic_callback(void *NotUsed, int argc, char **argv, char **azColName){
    (void)NotUsed;
    for (int i = 0; i < argc; i++) {
        printf("%s = %s | ", azColName[i], argv[i] ? argv[i] : "NULL");
    }
    printf("\n");
    return 0;
}

// ---------- DB wrapper ----------
struct DB {
    sqlite3* db = nullptr;
    bool open(const string &path) {
        if (sqlite3_open(path.c_str(), &db) != SQLITE_OK) {
            cout << "Can't open DB: " << sqlite3_errmsg(db) << "\n";
            return false;
        }
        // Enable foreign keys (good practice)
        sqlite3_exec(db, "PRAGMA foreign_keys = ON;", nullptr, nullptr, nullptr);
        return true;
    }
    void close() {
        if (db) sqlite3_close(db);
        db = nullptr;
    }

    ~DB() { close(); }

    bool table_exists(const string &name) {
        string q = "SELECT COUNT(1) FROM sqlite_master WHERE type='table' AND name = ?;";
        sqlite3_stmt* stmt = nullptr;
        if (sqlite3_prepare_v2(db, q.c_str(), -1, &stmt, nullptr) != SQLITE_OK) return false;
        sqlite3_bind_text(stmt, 1, name.c_str(), -1, SQLITE_TRANSIENT);
        bool exists = false;
        if (sqlite3_step(stmt) == SQLITE_ROW) {
            int count = sqlite3_column_int(stmt, 0);
            exists = (count > 0);
        }
        sqlite3_finalize(stmt);
        return exists;
    }

    bool id_exists(const string &table, const string &pk_col, int id) {
        string q = "SELECT 1 FROM " + table + " WHERE " + pk_col + " = ? LIMIT 1;";
        sqlite3_stmt* stmt = nullptr;
        if (sqlite3_prepare_v2(db, q.c_str(), -1, &stmt, nullptr) != SQLITE_OK) return false;
        sqlite3_bind_int(stmt, 1, id);
        bool found = false;
        if (sqlite3_step(stmt) == SQLITE_ROW) found = true;
        sqlite3_finalize(stmt);
        return found;
    }

    // Generic function to run a query with no parameters and print results
    void run_and_print(const string &sql) {
        sqlite3_stmt* stmt;
        if (sqlite3_prepare_v2(db, sql.c_str(), -1, &stmt, nullptr) != SQLITE_OK) {
            cout << "Query prepare error: " << sqlite3_errmsg(db) << "\n";
            return;
        }
        bool header_printed = false;
        while (sqlite3_step(stmt) == SQLITE_ROW) {
            if (!header_printed) {
                print_table_header(stmt);
                header_printed = true;
            }
            int cols = sqlite3_column_count(stmt);
            for (int i = 0; i < cols; ++i) {
                const unsigned char* txt = sqlite3_column_text(stmt, i);
                string val = txt ? reinterpret_cast<const char*>(txt) : "NULL";
                cout << std::left << std::setw(18) << val;
            }
            cout << "\n";
        }
        sqlite3_finalize(stmt);
        if (!header_printed) cout << "(no rows)\n";
    }
};

// ---------- App logic implementing menu operations ----------

void show_all_fields(DB &db) {
    cout << "\n-- All fields --\n";
    db.run_and_print("SELECT fld_fieldkey AS id, fld_farmerkey AS farmer_id, fld_soilkey AS soil_type, fld_area FROM field ORDER BY fld_fieldkey;");
}

void crops_by_season(DB &db) {
    cout << "Enter season_id: ";
    int sid; cin >> sid; cin.ignore();
    if (!db.id_exists("season", "s_seasonkey", sid)) {
        cout << "Season id not found.\n"; return;
    }
    string sql = "SELECT s.s_name AS season, c.c_name AS crop, COUNT(fc.fldc_fieldkey) as plantings "
                 "FROM season s JOIN crop c ON c.c_preferredseason = s.s_seasonkey "
                 "LEFT JOIN fieldcrop fc ON fc.fldc_cropkey = c.c_cropkey "
                 "WHERE s.s_seasonkey = ? GROUP BY c.c_cropkey;";
    sqlite3_stmt* stmt;
    if (sqlite3_prepare_v2(db.db, sql.c_str(), -1, &stmt, nullptr) != SQLITE_OK) {
        cout << "Prepare error\n"; return;
    }
    sqlite3_bind_int(stmt, 1, sid);
    bool printed = false;
    print_table_header(stmt);
    while (sqlite3_step(stmt) == SQLITE_ROW) {
        printed = true;
        int cols = sqlite3_column_count(stmt);
        for (int i = 0; i < cols; ++i) {
            const unsigned char* txt = sqlite3_column_text(stmt, i);
            string val = txt ? reinterpret_cast<const char*>(txt) : "NULL";
            cout << std::left << std::setw(18) << val;
        }
        cout << "\n";
    }
    sqlite3_finalize(stmt);
    if (!printed) cout << "(no rows)\n";
}

void avg_yield_per_field(DB &db) {
    cout << "\n-- Avg yield per field (aggregated) --\n";
    string sql = "SELECT fldc_fieldkey AS fieldkey, ROUND(AVG(fldc_yield), 2) AS avg_yield, COUNT(fldc_fieldkey) AS observations "
                 "FROM fieldcrop GROUP BY fldc_fieldkey ORDER BY fldc_fieldkey;";
    db.run_and_print(sql);
}

void latest_soil_sample_for_field(DB &db) {
    cout << "Enter field_id: ";
    int fid; cin >> fid; cin.ignore();
    if (!db.id_exists("field", "fld_fieldkey", fid)) { cout << "Field not found.\n"; return; }
    string sql = "SELECT * FROM soilsample WHERE ss_fieldkey = ? ORDER BY ss_sampledate DESC LIMIT 1;";
    sqlite3_stmt* stmt;
    if (sqlite3_prepare_v2(db.db, sql.c_str(), -1, &stmt, nullptr) != SQLITE_OK) { cout << "Prepare error\n"; return; }
    sqlite3_bind_int(stmt, 1, fid);
    if (sqlite3_step(stmt) == SQLITE_ROW) {
        print_table_header(stmt);
        int cols = sqlite3_column_count(stmt);
        for (int i = 0; i < cols; ++i) {
            const unsigned char* txt = sqlite3_column_text(stmt, i);
            string val = txt ? reinterpret_cast<const char*>(txt) : "NULL";
            cout << std::left << std::setw(18) << val;
        }
        cout << "\n";
    } else cout << "(no sample rows)\n";
    sqlite3_finalize(stmt);
}

void samples_exceeding_thresholds(DB &db) {
    cout << "Enter lead_limit (ppm) [example 100]: "; double lead; cin >> lead;
    cout << "Enter cadmium_limit (ppm) [example 0.48]: "; double cad; cin >> cad;
    cout << "Enter arsenic_limit (ppm) [example 10]: "; double as; cin >> as;
    cin.ignore();
    string sql = "SELECT ss.ss_samplekey, ss.ss_sampledate, fld.fld_fieldkey, f.f_farmerkey, f.f_name || ' ' || f.f_surname AS farmer_name, "
                 "ss.ss_lead_ppm, ss.ss_cadmium_ppm, ss.ss_arsenic_ppm "
                 "FROM soilsample ss JOIN field fld ON ss.ss_fieldkey = fld.fld_fieldkey JOIN farmer f ON fld.fld_farmerkey = f.f_farmerkey "
                 "WHERE (ss.ss_lead_ppm IS NOT NULL AND ss.ss_lead_ppm > ?) OR (ss.ss_cadmium_ppm IS NOT NULL AND ss.ss_cadmium_ppm > ?) OR (ss.ss_arsenic_ppm IS NOT NULL AND ss.ss_arsenic_ppm > ?) "
                 "ORDER BY ss.ss_sampledate DESC;";
    sqlite3_stmt* stmt;
    if (sqlite3_prepare_v2(db.db, sql.c_str(), -1, &stmt, nullptr) != SQLITE_OK) { cout << "Prepare error\n"; return; }
    sqlite3_bind_double(stmt, 1, lead);
    sqlite3_bind_double(stmt, 2, cad);
    sqlite3_bind_double(stmt, 3, as);
    bool printed = false;
    print_table_header(stmt);
    while (sqlite3_step(stmt) == SQLITE_ROW) {
        printed = true;
        int cols = sqlite3_column_count(stmt);
        for (int i = 0; i < cols; ++i) {
            const unsigned char* txt = sqlite3_column_text(stmt, i);
            string val = txt ? reinterpret_cast<const char*>(txt) : "NULL";
            cout << std::left << std::setw(18) << val;
        }
        cout << "\n";
    }
    sqlite3_finalize(stmt);
    if (!printed) cout << "(no rows)\n";
}

void fields_no_recent_maintenance(DB &db) {
    cout << "\n-- Fields with no maintenance in last 3 years (or never) --\n";
    string sql = R"(
    WITH last_maint AS (
      SELECT fldm_fieldkey, MAX(fldm_begindate) AS last_begindate
      FROM fieldmaintenance
      GROUP BY fldm_fieldkey
    )
    SELECT fld.fld_fieldkey AS fieldkey, fld.fld_farmerkey AS farmerkey, TRIM(f.f_name || ' ' || f.f_surname) AS farmer_name, fld.fld_soilkey AS soilkey, lm.last_begindate
    FROM field fld
    LEFT JOIN last_maint lm ON fld.fld_fieldkey = lm.fldm_fieldkey
    LEFT JOIN farmer f ON fld.fld_farmerkey = f.f_farmerkey
    WHERE lm.last_begindate IS NULL OR lm.last_begindate < date('now', '-3 years')
    ORDER BY (lm.last_begindate IS NOT NULL), lm.last_begindate;
    )";
    db.run_and_print(sql);
}

void avg_npk_by_soil_texture(DB &db) {
    cout << "\n-- Avg NPK by soil texture (requires >=5 samples) --\n";
    string sql = R"(
    SELECT st.st_soil_texture AS soil_texture, COUNT(ss.ss_samplekey) AS sample_count,
           ROUND(AVG(ss.ss_nitrogen_ppm),2) AS avg_nitrogen_ppm,
           ROUND(AVG(ss.ss_phosphorus_ppm),2) AS avg_phosphorus_ppm,
           ROUND(AVG(ss.ss_potassium_ppm),2) AS avg_potassium_ppm,
           ROUND(AVG(ss.ss_cec),2) AS avg_cec
    FROM soilsample ss
    JOIN field fld ON ss.ss_fieldkey = fld.fld_fieldkey
    JOIN soiltype st ON fld.fld_soilkey = st.st_soilkey
    GROUP BY st.st_soil_texture
    HAVING COUNT(ss.ss_samplekey) >= 5
    ORDER BY st.st_soilkey DESC;
    )";
    db.run_and_print(sql);
}

void total_yield_per_season(DB &db) {
    cout << "\n-- Total yield per season (aggregated) --\n";
    string sql = R"(
    SELECT s.s_seasonkey, s.s_name, ROUND(SUM(fc.fldc_yield),2) AS total_yield, COUNT(fc.fldc_fieldkey) AS plantings_count
    FROM season s
    JOIN crop c ON c.c_preferredseason = s.s_seasonkey
    JOIN fieldcrop fc ON fc.fldc_cropkey = c.c_cropkey
    GROUP BY s.s_seasonkey, s.s_name
    ORDER BY total_yield DESC;
    )";
    db.run_and_print(sql);
}

void crop_rotation_history(DB &db) {
    cout << "Enter field_id to view recent rotation: ";
    int fid; cin >> fid; cin.ignore();
    if (!db.id_exists("field", "fld_fieldkey", fid)) { cout << "Field not found.\n"; return; }
    string sql = R"(
    WITH crop_history AS (
      SELECT fc.fldc_fieldkey, fc.fldc_cropkey, fc.fldc_enddate,
             ROW_NUMBER() OVER (PARTITION BY fc.fldc_fieldkey ORDER BY fc.fldc_enddate DESC) AS rn
      FROM fieldcrop fc
      WHERE fc.fldc_fieldkey = ?
    )
    SELECT current_harvest.fldc_fieldkey, current_harvest.fldc_cropkey AS current_cropkey, previous_harvest.fldc_cropkey AS previous_cropkey,
           c1.c_name AS current_crop_name, c2.c_name AS previous_crop_name
    FROM crop_history current_harvest
    JOIN crop_history previous_harvest ON current_harvest.fldc_fieldkey = previous_harvest.fldc_fieldkey
    JOIN crop c1 ON current_harvest.fldc_cropkey = c1.c_cropkey
    JOIN crop c2 ON previous_harvest.fldc_cropkey = c2.c_cropkey
    WHERE current_harvest.rn = 1 AND previous_harvest.rn = 2 AND current_harvest.fldc_cropkey <> previous_harvest.fldc_cropkey;
    )";
    sqlite3_stmt* stmt;
    if (sqlite3_prepare_v2(db.db, sql.c_str(), -1, &stmt, nullptr) != SQLITE_OK) { cout << "Prepare error\n"; return; }
    sqlite3_bind_int(stmt, 1, fid);
    bool printed = false;
    print_table_header(stmt);
    while (sqlite3_step(stmt) == SQLITE_ROW) {
        printed = true;
        int cols = sqlite3_column_count(stmt);
        for (int i = 0; i < cols; ++i) {
            const unsigned char* txt = sqlite3_column_text(stmt, i);
            string val = txt ? reinterpret_cast<const char*>(txt) : "NULL";
            cout << std::left << std::setw(18) << val;
        }
        cout << "\n";
    }
    sqlite3_finalize(stmt);
    if (!printed) cout << "(no rotation info found)\n";
}

// ---------- Insert operations (safe, parameterized) ----------

void insert_fieldcrop(DB &db) {
    cout << "Inserting new fieldcrop entry.\n";
    int field_id, crop_id;
    string bdate, edate;
    double yield; string unit;
    cout << "field_id: "; cin >> field_id;
    if (!db.id_exists("field", "fld_fieldkey", field_id)) { cout << "Field id not found.\n"; cin.ignore(); return; }
    cout << "crop_id: "; cin >> crop_id;
    if (!db.id_exists("crop", "c_cropkey", crop_id)) { cout << "Crop id not found.\n"; cin.ignore(); return; }
    cout << "begin_date (YYYY-MM-DD): "; cin >> bdate;
    if (!valid_date(bdate)) { cout << "Invalid date format.\n"; cin.ignore(); return; }
    cout << "end_date (YYYY-MM-DD or empty if ongoing): "; cin >> edate;
    if (!edate.empty() && !valid_date(edate)) { cout << "Invalid date format.\n"; cin.ignore(); return; }
    cout << "yield (>=0): "; cin >> yield;
    if (yield < 0) { cout << "Yield must be non-negative.\n"; cin.ignore(); return; }
    cout << "unit (text): "; cin >> unit;
    cin.ignore();

    string sql = "INSERT INTO fieldcrop (fldc_fieldkey, fldc_cropkey, fldc_begindate, fldc_enddate, fldc_yield, fldc_yield_unit) VALUES (?, ?, ?, ?, ?, ?);";
    sqlite3_stmt* stmt;
    if (sqlite3_prepare_v2(db.db, sql.c_str(), -1, &stmt, nullptr) != SQLITE_OK) { cout << "Prepare error: " << sqlite3_errmsg(db.db) << "\n"; return; }
    sqlite3_bind_int(stmt, 1, field_id);
    sqlite3_bind_int(stmt, 2, crop_id);
    sqlite3_bind_text(stmt, 3, bdate.c_str(), -1, SQLITE_TRANSIENT);
    if (edate.empty()) sqlite3_bind_null(stmt, 4); else sqlite3_bind_text(stmt, 4, edate.c_str(), -1, SQLITE_TRANSIENT);
    sqlite3_bind_double(stmt, 5, yield);
    sqlite3_bind_text(stmt, 6, unit.c_str(), -1, SQLITE_TRANSIENT);
    if (sqlite3_step(stmt) != SQLITE_DONE) {
        cout << "Insert failed: " << sqlite3_errmsg(db.db) << "\n";
    } else cout << "Inserted fieldcrop row successfully.\n";
    sqlite3_finalize(stmt);
}

void insert_soilsample(DB &db) {
    cout << "Inserting new soilsample entry.\n";
    int field_id;
    string sdate;
    double ph, nppm, pppm, kppm, om;
    cout << "field_id: "; cin >> field_id;
    if (!db.id_exists("field", "fld_fieldkey", field_id)) { cout << "Field id not found.\n"; cin.ignore(); return; }
    cout << "sample_date (YYYY-MM-DD): "; cin >> sdate;
    if (!valid_date(sdate)) { cout << "Invalid date format.\n"; cin.ignore(); return; }
    cout << "ph (3.0 - 9.0): "; cin >> ph;
    if (ph < 3.0 || ph > 9.0) { cout << "ph out of expected range.\n"; cin.ignore(); return; }
    cout << "nitrogen_ppm (>=0): "; cin >> nppm;
    if (nppm < 0) { cout << "must be >=0\n"; cin.ignore(); return; }
    cout << "phosphorus_ppm (>=0): "; cin >> pppm;
    if (pppm < 0) { cout << "must be >=0\n"; cin.ignore(); return; }
    cout << "potassium_ppm (>=0): "; cin >> kppm;
    if (kppm < 0) { cout << "must be >=0\n"; cin.ignore(); return; }
    cout << "organic_matter_pct (>=0): "; cin >> om;
    if (om < 0) { cout << "must be >=0\n"; cin.ignore(); return; }
    cin.ignore();

    string sql = R"(INSERT INTO soilsample
      (ss_fieldkey, ss_sampledate, ss_ph, ss_nitrogen_ppm, ss_phosphorus_ppm, ss_potassium_ppm, ss_organicmatter_pct)
      VALUES (?, ?, ?, ?, ?, ?, ?);)";
    sqlite3_stmt* stmt;
    if (sqlite3_prepare_v2(db.db, sql.c_str(), -1, &stmt, nullptr) != SQLITE_OK) { cout << "Prepare error\n"; return; }
    sqlite3_bind_int(stmt, 1, field_id);
    sqlite3_bind_text(stmt, 2, sdate.c_str(), -1, SQLITE_TRANSIENT);
    sqlite3_bind_double(stmt, 3, ph);
    sqlite3_bind_double(stmt, 4, nppm);
    sqlite3_bind_double(stmt, 5, pppm);
    sqlite3_bind_double(stmt, 6, kppm);
    sqlite3_bind_double(stmt, 7, om);
    if (sqlite3_step(stmt) != SQLITE_DONE) {
        cout << "Insert failed: " << sqlite3_errmsg(db.db) << "\n";
    } else cout << "Inserted soilsample row successfully.\n";
    sqlite3_finalize(stmt);
}

// ---------- Main menu ----------
void show_menu() {
    cout << "\n====== AIMS CLI MENU ======\n";
    cout << "1) Show all fields\n";
    cout << "2) View crops by season\n";
    cout << "3) Avg yield per field\n";
    cout << "4) Latest soil sample for field\n";
    cout << "5) Samples exceeding thresholds (lead/cadmium/arsenic)\n";
    cout << "6) Fields with no recent maintenance (>3 years)\n";
    cout << "7) Avg NPK by soil texture (>=5 samples)\n";
    cout << "8) Total yield per season\n";
    cout << "9) Crop rotation history for a field\n";
    cout << "10) Insert new fieldcrop (planting/harvest)\n";
    cout << "11) Insert new soilsample\n";
    cout << "0) Exit\n";
    cout << "Choose option: ";
}

int main(int argc, char** argv) {
    if (argc < 2) {
        cout << "Usage: " << argv[0] << " /path/to/aims.sqlite\n";
        return 1;
    }
    string dbpath = argv[1];
    if (!file_exists(dbpath)) { cout << "DB file not found: " << dbpath << "\n"; return 1; }

    DB db;
    if (!db.open(dbpath)) return 1;

    // quick sanity: ensure main tables exist
    vector<string> must = {"field","crop","fieldcrop","soilsample","farmer","season"};
    for (auto &t : must) {
        if (!db.table_exists(t)) {
            cout << "Warning: required table '" << t << "' not found in DB. The program may error.\n";
        }
    }

    while (true) {
        show_menu();
        int opt; if (!(cin >> opt)) { cout << "Invalid input. Exiting.\n"; break; }
        cin.ignore();
        switch (opt) {
            case 1: show_all_fields(db); break;
            case 2: crops_by_season(db); break;
            case 3: avg_yield_per_field(db); break;
            case 4: latest_soil_sample_for_field(db); break;
            case 5: samples_exceeding_thresholds(db); break;
            case 6: fields_no_recent_maintenance(db); break;
            case 7: avg_npk_by_soil_texture(db); break;
            case 8: total_yield_per_season(db); break;
            case 9: crop_rotation_history(db); break;
            case 10: insert_fieldcrop(db); break;
            case 11: insert_soilsample(db); break;
            case 0: cout << "Goodbye.\n"; db.close(); return 0;
            default: cout << "Unknown option.\n";
        }
    }

    db.close();
    return 0;
}
