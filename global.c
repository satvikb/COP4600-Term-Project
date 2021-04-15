#include "global.h"
#include <vector>
using namespace std;

map<string,string> envMap;
map<string,string> aliasMap;
map<string, string> systemUsers;
string CURRENT_DIR;
// TODO maybe use list?
struct vector<command> commandTable;

TStrStrMap::const_iterator FindPrefix(const TStrStrMap& map, const string& search_for) {
    TStrStrMap::const_iterator i = map.lower_bound(search_for);
    if (i != map.end()) {
        const string& key = i->first;
        if (key.compare(0, search_for.size(), search_for) == 0) // Really a prefix?
            return i;
    }
    return map.end();
}