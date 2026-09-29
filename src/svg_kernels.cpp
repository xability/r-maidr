// String kernels behind the SVG export (R/svg_export.R).
//
// Each function here reproduces an R helper exactly -- same bytes out for
// the same input, NA handling included -- and exists only because the R
// version walks every shape, vertex or style declaration of a chart through
// several regular expressions. tests/testthat/test-svg-kernels.R holds the
// R originals and checks the two agree.

#include <Rcpp.h>
#include <R_ext/Utils.h>

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <string>
#include <unordered_map>
#include <utility>
#include <vector>

using namespace Rcpp;

namespace {

// -- strings in and out ------------------------------------------------------

bool is_ascii(const std::string& s) {
  for (unsigned char c : s) {
    if (c > 127) return false;
  }
  return true;
}

SEXP make_string(const std::string& s) {
  return Rf_mkCharLenCE(s.data(), static_cast<int>(s.size()),
                        is_ascii(s) ? CE_NATIVE : CE_UTF8);
}

std::string utf8(SEXP chr) {
  return std::string(Rf_translateCharUTF8(chr));
}

bool is_ws(char c) {
  return c == ' ' || c == '\t' || c == '\r' || c == '\n';
}

// trimws(): strips [ \t\r\n] from both ends.
std::string trim(const std::string& s) {
  size_t b = 0, e = s.size();
  while (b < e && is_ws(s[b])) ++b;
  while (e > b && is_ws(s[e - 1])) --e;
  return s.substr(b, e - b);
}

bool is_digit(char c) {
  return c >= '0' && c <= '9';
}

// -- numbers -----------------------------------------------------------------

// as.numeric() on one string: R's own parser, so a value parses to the very
// double R would give it.
double parse_num(const std::string& s, bool na) {
  if (na) return NA_REAL;
  const char* p = s.c_str();
  char* end = nullptr;
  double x = R_strtod(p, &end);
  if (end == p) return NA_REAL;
  while (*end && is_ws(*end)) ++end;
  return *end ? NA_REAL : x;
}

// svg_trim(): sub("(\\.[0-9]*[1-9])0+$", "\\1", sub("\\.0+$", "", x)).
std::string trim_zeros(std::string s) {
  size_t dot = s.rfind('.');
  if (dot == std::string::npos) return s;
  bool zeros = dot + 1 < s.size();
  for (size_t i = dot + 1; i < s.size() && zeros; ++i) zeros = s[i] == '0';
  if (zeros) {
    // The second pattern then runs on what the first left.
    s.resize(dot);
    dot = s.rfind('.');
    if (dot == std::string::npos) return s;
  }
  if (s.empty() || s.back() != '0') return s;
  size_t last_nonzero = std::string::npos;
  for (size_t i = dot + 1; i < s.size(); ++i) {
    if (!is_digit(s[i])) return s;
    if (s[i] != '0') last_nonzero = i;
  }
  if (last_nonzero == std::string::npos) return s;
  return s.substr(0, last_nonzero + 1);
}

// svg_fmt() on a batch: formatC(v, format = "f", digits = 2), then
// svg_trim(). formatC() writes the non-finite values of one call right-
// justified to a shared width ("NA" counting as three wide), so the width
// is a property of the batch, not of the value.
std::vector<std::string> fmt_batch(const std::vector<double>& v) {
  std::vector<std::string> out(v.size());
  size_t width = 0;
  bool special = false;
  char buf[512];
  for (size_t i = 0; i < v.size(); ++i) {
    double x = v[i];
    if (std::isfinite(x)) {
      std::snprintf(buf, sizeof(buf), "%.2f", x);
      out[i] = trim_zeros(buf);
      continue;
    }
    special = true;
    if (ISNA(x)) {
      out[i] = "NA";
      width = std::max<size_t>(width, 3);
    } else if (ISNAN(x)) {
      out[i] = "NaN";
    } else {
      out[i] = x > 0 ? "Inf" : "-Inf";
    }
    width = std::max(width, out[i].size());
  }
  if (special) {
    for (size_t i = 0; i < v.size(); ++i) {
      if (!std::isfinite(v[i]) && out[i].size() < width) {
        out[i] = std::string(width - out[i].size(), ' ') + out[i];
      }
    }
  }
  return out;
}

std::string fmt_one(double x) {
  return fmt_batch(std::vector<double>(1, x))[0];
}

// -- attributes --------------------------------------------------------------

// svg_attr() on one line: the value of the first ` name='...'`. Returns
// false for a line without the attribute. A line whose value is never
// closed is returned whole, as sub() returns a line its pattern misses.
bool attr_value(const std::string& line, const std::string& key,
                std::string* value) {
  size_t at = line.find(key);
  if (at == std::string::npos) return false;
  size_t start = at + key.size();
  size_t close = line.find('\'', start);
  *value = close == std::string::npos ? line : line.substr(start, close - start);
  return true;
}

}  // namespace

//' svg_trim() in C++
//' @param x Character vector.
//' @return `x` without the trailing zeros of a decimal part.
//' @keywords internal
//' @noRd
// [[Rcpp::export]]
CharacterVector svg_trim_cpp(CharacterVector x) {
  R_xlen_t n = x.size();
  CharacterVector out(n);
  for (R_xlen_t i = 0; i < n; ++i) {
    SEXP s = x[i];
    out[i] = s == NA_STRING ? NA_STRING : make_string(trim_zeros(utf8(s)));
  }
  return out;
}

//' svg_fmt() in C++
//' @param v Numeric vector.
//' @return Character vector, two places without trailing zeros.
//' @keywords internal
//' @noRd
// [[Rcpp::export]]
CharacterVector svg_fmt_cpp(NumericVector v) {
  std::vector<double> x(v.begin(), v.end());
  std::vector<std::string> s = fmt_batch(x);
  CharacterVector out(s.size());
  for (size_t i = 0; i < s.size(); ++i) out[i] = make_string(s[i]);
  return out;
}

//' svg_attr() in C++
//' @param lines Character vector of element lines.
//' @param name Attribute name.
//' @return Each line's attribute value, NA where it has none.
//' @keywords internal
//' @noRd
// [[Rcpp::export]]
CharacterVector svg_attr_cpp(CharacterVector lines, std::string name) {
  std::string key = " " + name + "='";
  R_xlen_t n = lines.size();
  CharacterVector out(n);
  std::string value;
  for (R_xlen_t i = 0; i < n; ++i) {
    SEXP s = lines[i];
    if (s == NA_STRING || !attr_value(utf8(s), key, &value)) {
      out[i] = NA_STRING;
    } else {
      out[i] = make_string(value);
    }
  }
  return out;
}

//' svg_flip_points() in C++
//' @param points Character vector of "x,y x,y" lists.
//' @param h Page height.
//' @return The lists with every y flipped about `h`.
//' @keywords internal
//' @noRd
// [[Rcpp::export]]
CharacterVector svg_flip_points_cpp(CharacterVector points, double h) {
  R_xlen_t n = points.size();
  // One svg_fmt() call formats every y of every list, so the batch spans
  // them all; x is only trimmed.
  std::vector<R_xlen_t> owner;
  std::vector<std::string> xs;
  std::vector<bool> x_na;
  std::vector<double> ys;
  for (R_xlen_t i = 0; i < n; ++i) {
    SEXP s = points[i];
    if (s == NA_STRING) {
      owner.push_back(i);
      xs.push_back("");
      x_na.push_back(true);
      ys.push_back(NA_REAL);
      continue;
    }
    std::string str = trim(utf8(s));
    // strsplit(, "[ ]+"): an empty string has no pieces, a leading run of
    // spaces gives one empty piece, a trailing run none.
    size_t pos = 0;
    while (pos < str.size()) {
      size_t sp = str.find(' ', pos);
      std::string piece = str.substr(pos, sp == std::string::npos ? std::string::npos : sp - pos);
      owner.push_back(i);
      size_t comma = piece.find(',');
      if (comma == std::string::npos) {
        xs.push_back(piece);
        x_na.push_back(false);
        ys.push_back(NA_REAL);
      } else {
        size_t comma2 = piece.find(',', comma + 1);
        xs.push_back(piece.substr(0, comma));
        x_na.push_back(false);
        std::string y = piece.substr(comma + 1, comma2 == std::string::npos ? std::string::npos : comma2 - comma - 1);
        ys.push_back(h - parse_num(y, false));
      }
      if (sp == std::string::npos) break;
      pos = sp;
      while (pos < str.size() && str[pos] == ' ') ++pos;
    }
  }
  std::vector<std::string> fy = fmt_batch(ys);
  std::vector<std::string> joined(n);
  std::vector<bool> any(n, false);
  for (size_t k = 0; k < owner.size(); ++k) {
    std::string& j = joined[owner[k]];
    if (any[owner[k]]) j += " ";
    j += x_na[k] ? std::string("NA") : trim_zeros(xs[k]);
    j += ",";
    j += fy[k];
    any[owner[k]] = true;
  }
  // split() drops a list with no pieces, which shortens the result.
  std::vector<std::string> kept;
  for (R_xlen_t i = 0; i < n; ++i) {
    if (any[i]) kept.push_back(joined[i]);
  }
  CharacterVector out(kept.size());
  for (size_t i = 0; i < kept.size(); ++i) out[i] = make_string(kept[i]);
  return out;
}

//' svg_flip_path() in C++
//' @param d Character vector of absolute M/L/Z paths.
//' @param h Page height.
//' @return The paths with every y flipped about `h`.
//' @keywords internal
//' @noRd
// [[Rcpp::export]]
CharacterVector svg_flip_path_cpp(CharacterVector d, double h) {
  R_xlen_t n = d.size();
  CharacterVector out(n);
  for (R_xlen_t k = 0; k < n; ++k) {
    SEXP s = d[k];
    if (s == NA_STRING) {
      out[k] = make_string("NA");
      continue;
    }
    // gsub("([MLZ])", " \\1 ") then strsplit on "[ ,]+", empty pieces
    // dropped.
    std::string str = utf8(s);
    std::vector<std::string> tok;
    std::string cur;
    for (char c : str) {
      if (c == 'M' || c == 'L' || c == 'Z') {
        if (!cur.empty()) tok.push_back(cur);
        cur.clear();
        tok.push_back(std::string(1, c));
      } else if (c == ' ' || c == ',') {
        if (!cur.empty()) tok.push_back(cur);
        cur.clear();
      } else {
        cur += c;
      }
    }
    if (!cur.empty()) tok.push_back(cur);

    auto numeric = [](const std::string& t) {
      return !t.empty() && (is_digit(t[0]) || t[0] == '.' || t[0] == '-');
    };
    std::vector<std::string> res(tok.size());
    for (size_t i = 0; i < tok.size(); ++i) {
      res[i] = numeric(tok[i]) ? trim_zeros(tok[i]) : tok[i];
    }
    // A y beyond the last token is NA, and assigning it grows the result
    // as `out[i] <-` does, the gap filled with NA.
    auto set_y = [&](size_t at) {
      double y = at < tok.size() ? parse_num(tok[at], false) : NA_REAL;
      if (at >= res.size()) res.resize(at + 1, "NA");
      res[at] = fmt_one(h - y);
    };
    size_t i = 0;
    while (i < tok.size()) {
      if (tok[i] == "M" || tok[i] == "L") {
        set_y(i + 2);
        i += 3;
      } else if (numeric(tok[i])) {
        set_y(i + 1);
        i += 2;
      } else {
        i += 1;
      }
    }
    std::string joined;
    for (size_t j = 0; j < res.size(); ++j) {
      if (j) joined += " ";
      joined += res[j];
    }
    out[k] = make_string(joined);
  }
  return out;
}

namespace {

// A named character vector as R subsets it by name: the first element of a
// name wins, "" never matches, and a value may be NA.
struct Decl {
  std::string name;
  std::string value;
  bool na;
};

class Decls {
 public:
  std::vector<Decl> items;

  const Decl* find(const std::string& name) const {
    if (name.empty()) return nullptr;
    for (const Decl& d : items) {
      if (d.name == name) return &d;
    }
    return nullptr;
  }
  bool has_name(const std::string& name) const {
    for (const Decl& d : items) {
      if (d.name == name) return true;
    }
    return false;
  }
  // val[["name"]] <- value: the first element of the name, else appended.
  void set(const std::string& name, const std::string& value, bool na = false) {
    for (Decl& d : items) {
      if (d.name == name) {
        d.value = value;
        d.na = na;
        return;
      }
    }
    items.push_back(Decl{name, value, na});
  }
};

void add_unique(std::vector<std::string>* v, const std::string& s) {
  for (const std::string& e : *v) {
    if (e == s) return;
  }
  v->push_back(s);
}

bool contains(const std::vector<std::string>& v, const std::string& s) {
  for (const std::string& e : v) {
    if (e == s) return true;
  }
  return false;
}

bool is_hex6(const std::string& s) {
  if (s.size() != 7 || s[0] != '#') return false;
  for (size_t i = 1; i < 7; ++i) {
    char c = s[i];
    bool hex = is_digit(c) || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F');
    if (!hex) return false;
  }
  return true;
}

bool all_num_chars(const std::string& s, size_t end) {
  if (end == 0) return false;
  for (size_t i = 0; i < end; ++i) {
    if (!is_digit(s[i]) && s[i] != '.') return false;
  }
  return true;
}

std::string hex_to_rgb(const std::string& s) {
  auto byte = [&](size_t at) {
    return std::to_string(std::stoi(s.substr(at, 2), nullptr, 16));
  };
  return "rgb(" + byte(1) + "," + byte(3) + "," + byte(5) + ")";
}

struct StyleTables {
  std::vector<std::string> gp_names;
  std::vector<std::vector<std::string>> gp_attrs;
  Decls defaults;
  Decls aliases;
  std::string sans;
};

std::string font_stack(const StyleTables& t, const std::string& family) {
  const Decl* a = t.aliases.find(family);
  if (a && !a->na) return a->value;
  return family.empty() ? t.sans : family + ", " + t.sans;
}

std::string convert_style(const StyleTables& t, const std::string& style,
                          bool text, bool own_na, const std::string& own,
                          bool line) {
  Decls val;
  size_t pos = 0;
  while (pos <= style.size()) {
    size_t semi = style.find(';', pos);
    std::string d = trim(style.substr(pos, semi == std::string::npos ? std::string::npos : semi - pos));
    if (!d.empty()) {
      size_t colon = d.find(':');
      std::string k = trim(colon == std::string::npos ? d : d.substr(0, colon));
      std::string v = trim(colon == std::string::npos ? d : d.substr(colon + 1));
      if (k != "white-space") val.items.push_back(Decl{k, v, false});
    }
    if (semi == std::string::npos) break;
    pos = semi + 1;
  }

  std::vector<std::string> want;
  if (own_na) {
    for (const Decl& d : val.items) add_unique(&want, d.name);
    add_unique(&want, "fill");
    add_unique(&want, "stroke");
  } else {
    std::vector<std::string> set;
    size_t p = 0;
    while (p < own.size()) {
      size_t comma = own.find(',', p);
      set.push_back(own.substr(p, comma == std::string::npos ? std::string::npos : comma - p));
      if (comma == std::string::npos) break;
      p = comma + 1;
    }
    std::vector<std::string> hit;
    for (const std::string& s : set) {
      if (contains(t.gp_names, s)) add_unique(&hit, s);
    }
    for (const std::string& s : hit) {
      for (size_t g = 0; g < t.gp_names.size(); ++g) {
        if (t.gp_names[g] != s) continue;
        for (const std::string& a : t.gp_attrs[g]) add_unique(&want, a);
        break;
      }
    }
    if (val.has_name("fill-rule")) want.push_back("fill-rule");
    if (text) {
      add_unique(&want, "fill");
      add_unique(&want, "fill-opacity");
      add_unique(&want, "font-size");
      add_unique(&want, "font-family");
    }
  }

  std::vector<std::string> miss;
  for (const std::string& w : want) {
    if (!val.has_name(w)) add_unique(&miss, w);
  }
  for (const std::string& m : miss) {
    const Decl* def = t.defaults.find(m);
    val.items.push_back(Decl{m, def ? def->value : "", def ? def->na : true});
  }
  if (text) {
    // gridSVG painted a label's colour as its stroke as well as its fill.
    if (contains(miss, "fill")) val.set("fill", "#000000");
    if (contains(want, "stroke")) {
      const Decl* fill = val.find("fill");
      if (!fill) stop("svg_style_attrs: a text element without a fill");
      Decl f = *fill;
      val.set("stroke", f.value, f.na);
      const Decl* fo = val.find("fill-opacity");
      if (!fo || fo->na) {
        val.set("stroke-opacity", "1");
      } else {
        std::string v = fo->value;
        val.set("stroke-opacity", v);
      }
    }
  }

  Decls kept;
  for (const std::string& w : want) {
    const Decl* d = val.find(w);
    if (d && !d->na) kept.items.push_back(Decl{w, d->value, false});
  }
  if (line) kept.set("fill", "none");

  std::string out;
  for (Decl& d : kept.items) {
    std::string& v = d.value;
    if (is_hex6(v)) v = hex_to_rgb(v);
    if (v.size() > 2 && v.compare(v.size() - 2, 2, "px") == 0 &&
        all_num_chars(v, v.size() - 2)) {
      v = v.substr(0, v.size() - 2);
    }
    if (all_num_chars(v, v.size())) v = trim_zeros(v);
    if (d.name == "font-family") {
      std::string fam;
      for (char c : v) {
        if (c != '"') fam += c;
      }
      v = font_stack(t, fam);
    }
    out += " " + d.name + "=\"" + v + "\"";
  }
  return out;
}

Decls named_chr(CharacterVector x) {
  Decls out;
  CharacterVector nm = x.names();
  for (R_xlen_t i = 0; i < x.size(); ++i) {
    SEXP v = x[i];
    out.items.push_back(Decl{utf8(nm[i]), v == NA_STRING ? "" : utf8(v),
                             v == NA_STRING});
  }
  return out;
}

}  // namespace

//' svg_style_attrs() in C++
//'
//' @param style,text,own,line As for [svg_style_attrs()], all full length.
//' @param gp_map `svg_gp_attr_map`.
//' @param defaults `svg_style_defaults`.
//' @param aliases `svg_font_aliases()`.
//' @param sans The sans-serif font stack.
//' @return Character vector of attribute strings.
//' @keywords internal
//' @noRd
// [[Rcpp::export]]
CharacterVector svg_style_attrs_cpp(CharacterVector style, LogicalVector text,
                                    CharacterVector own, LogicalVector line,
                                    List gp_map, CharacterVector defaults,
                                    CharacterVector aliases, std::string sans) {
  StyleTables t;
  CharacterVector gp_names = gp_map.names();
  for (R_xlen_t i = 0; i < gp_map.size(); ++i) {
    t.gp_names.push_back(utf8(gp_names[i]));
    CharacterVector attrs = gp_map[i];
    std::vector<std::string> a;
    for (R_xlen_t j = 0; j < attrs.size(); ++j) a.push_back(utf8(attrs[j]));
    t.gp_attrs.push_back(a);
  }
  t.defaults = named_chr(defaults);
  if (aliases.size()) t.aliases = named_chr(aliases);
  t.sans = sans;

  R_xlen_t n = style.size();
  CharacterVector out(n);
  // The R version converts each distinct paste(text, line, own, style) once;
  // so does this, keyed the same way.
  std::unordered_map<std::string, std::string> seen;
  for (R_xlen_t i = 0; i < n; ++i) {
    if (text[i] == NA_LOGICAL || line[i] == NA_LOGICAL) {
      stop("svg_style_attrs: `text` and `line` must not be NA");
    }
    SEXP s = style[i];
    SEXP o = own[i];
    std::string st = s == NA_STRING ? "" : utf8(s);
    bool own_na = o == NA_STRING;
    std::string ow = own_na ? "NA" : utf8(o);
    std::string key = std::string(text[i] ? "1" : "0") + "\r" +
                      (line[i] ? "1" : "0") + "\r" + ow + "\r" + st;
    auto it = seen.find(key);
    if (it == seen.end()) {
      std::string conv = convert_style(t, st, text[i], own_na, ow, line[i]);
      it = seen.emplace(key, conv).first;
    }
    out[i] = make_string(it->second);
  }
  return out;
}
