// Kernels behind the maidr-data payload (R/svg_utils.R) and the ggplot2
// heatmap grid (R/ggplot2_heatmap_layer_processor.R).

#include <Rcpp.h>
#include <Rversion.h>

#include <cstring>
#include <initializer_list>
#include <string>
#include <vector>

using namespace Rcpp;

namespace {

// R 4.5 took ATTRIB() out of the API in favour of these; older R has only
// ATTRIB().
#if R_VERSION >= R_Version(4, 5, 0)
SEXP count_one(SEXP, SEXP, void* data) {
  ++*static_cast<int*>(data);
  return NULL;
}
int attrib_count(SEXP x) {
  int n = 0;
  R_mapAttrib(x, count_one, &n);
  return n;
}
bool has_attrib(SEXP x) {
  return ANY_ATTRIB(x);
}
#else
int attrib_count(SEXP x) {
  int n = 0;
  for (SEXP a = ATTRIB(x); a != R_NilValue; a = CDR(a)) ++n;
  return n;
}
bool has_attrib(SEXP x) {
  return ATTRIB(x) != R_NilValue;
}
#endif

bool same_string(SEXP a, SEXP b) {
  if (a == b) return true;
  if (a == NA_STRING || b == NA_STRING) return false;
  return std::strcmp(Rf_translateCharUTF8(a), Rf_translateCharUTF8(b)) == 0;
}

bool scalar_type(int type) {
  return type == LGLSXP || type == INTSXP || type == REALSXP || type == STRSXP;
}

// identical() on two character vectors of names.
bool same_names(SEXP a, SEXP b) {
  if (a == b) return true;
  if (TYPEOF(a) != STRSXP || TYPEOF(b) != STRSXP) return false;
  R_xlen_t n = XLENGTH(a);
  if (XLENGTH(b) != n || has_attrib(a) || has_attrib(b)) return false;
  for (R_xlen_t i = 0; i < n; ++i) {
    if (!same_string(STRING_ELT(a, i), STRING_ELT(b, i))) return false;
  }
  return true;
}

// is_flat_record(): a list whose only attribute is `names`, identical to
// the run's, and whose every field is one attribute-free value of the
// run's type in that position.
bool flat_record(SEXP record, SEXP fields, const std::vector<int>& types) {
  if (TYPEOF(record) != VECSXP) return false;
  if (attrib_count(record) != 1) return false;
  SEXP names = Rf_getAttrib(record, R_NamesSymbol);
  if (names == R_NilValue || !same_names(names, fields)) return false;
  R_xlen_t n = XLENGTH(record);
  if (n != static_cast<R_xlen_t>(types.size())) return false;
  for (R_xlen_t j = 0; j < n; ++j) {
    SEXP value = VECTOR_ELT(record, j);
    if (TYPEOF(value) != types[j] || XLENGTH(value) != 1 || has_attrib(value)) {
      return false;
    }
  }
  return true;
}

}  // namespace

//' A run of flat records as a data frame, in C++
//'
//' The check [is_record_run()] makes and the columns [records_as_frames()]
//' builds, in one pass.
//'
//' @param node A non-empty list.
//' @return The data frame, `NULL` when `node` is not a run of flat records,
//'   or `NA` when it holds something only the R version decides (a pairlist
//'   record).
//' @keywords internal
//' @noRd
// [[Rcpp::export]]
SEXP record_run_frame_cpp(SEXP node) {
  if (TYPEOF(node) != VECSXP || XLENGTH(node) == 0) return R_NilValue;
  if (Rf_getAttrib(node, R_NamesSymbol) != R_NilValue) return R_NilValue;
  R_xlen_t n = XLENGTH(node);
  for (R_xlen_t i = 0; i < n; ++i) {
    if (TYPEOF(VECTOR_ELT(node, i)) == LISTSXP) return Rf_ScalarLogical(NA_LOGICAL);
  }
  SEXP first = VECTOR_ELT(node, 0);
  if (TYPEOF(first) != VECSXP) return R_NilValue;
  SEXP fields = Rf_getAttrib(first, R_NamesSymbol);
  R_xlen_t nf = XLENGTH(first);
  // is_record_schema(): unique, non-empty, non-NA names over scalar types.
  if (nf == 0 || fields == R_NilValue || XLENGTH(fields) != nf) return R_NilValue;
  std::vector<int> types(nf);
  for (R_xlen_t j = 0; j < nf; ++j) {
    SEXP f = STRING_ELT(fields, j);
    if (f == NA_STRING || LENGTH(f) == 0) return R_NilValue;
    types[j] = TYPEOF(VECTOR_ELT(first, j));
    if (!scalar_type(types[j])) return R_NilValue;
  }
  if (Rf_any_duplicated(fields, FALSE)) return R_NilValue;
  for (R_xlen_t i = 0; i < n; ++i) {
    if (!flat_record(VECTOR_ELT(node, i), fields, types)) return R_NilValue;
  }

  SEXP columns = PROTECT(Rf_allocVector(VECSXP, nf));
  for (R_xlen_t j = 0; j < nf; ++j) {
    SEXP col = PROTECT(Rf_allocVector(types[j], n));
    for (R_xlen_t i = 0; i < n; ++i) {
      SEXP value = VECTOR_ELT(VECTOR_ELT(node, i), j);
      switch (types[j]) {
        case LGLSXP: LOGICAL(col)[i] = LOGICAL(value)[0]; break;
        case INTSXP: INTEGER(col)[i] = INTEGER(value)[0]; break;
        case REALSXP: REAL(col)[i] = REAL(value)[0]; break;
        default: SET_STRING_ELT(col, i, STRING_ELT(value, 0));
      }
    }
    SET_VECTOR_ELT(columns, j, col);
    UNPROTECT(1);
  }
  // structure(columns, class = "data.frame", row.names = .set_row_names(n)),
  // attributes in that order.
  Rf_setAttrib(columns, R_NamesSymbol, fields);
  Rf_setAttrib(columns, R_ClassSymbol, Rf_mkString("data.frame"));
  SEXP rn = PROTECT(Rf_allocVector(INTSXP, 2));
  INTEGER(rn)[0] = NA_INTEGER;
  INTEGER(rn)[1] = -static_cast<int>(n);
  Rf_setAttrib(columns, R_RowNamesSymbol, rn);
  UNPROTECT(2);
  return columns;
}

//' The source row each heatmap cell takes its value from, in C++
//'
//' For every requested cell, the first source row whose
//' `x == x_level & y == y_level` is not `FALSE`, as the per-cell scan it
//' replaces took it: a row whose x or y is missing compares `NA`, which
//' selects the row but not its value.
//'
//' @param sx,sy Each source row's x and y level (1-based), `0` for a value
//'   that equals no level and `NA` for a missing one.
//' @param nx,ny The number of x and y levels.
//' @param cx,cy The cells asked for, as x and y levels.
//' @return For each cell, the row as a positive index when it matched
//'   exactly, a negative one when it matched through a missing value, and
//'   `0` when no row matched.
//' @keywords internal
//' @noRd
// [[Rcpp::export]]
IntegerVector heat_cell_rows_cpp(IntegerVector sx, IntegerVector sy, int nx,
                                 int ny, IntegerVector cx, IntegerVector cy) {
  const int none = NA_INTEGER;
  R_xlen_t n = sx.size();
  if (sy.size() != n) stop("heat_cell_rows_cpp: sx and sy differ in length");
  // First row, 1-based, for each exact cell, for a missing x at each y
  // level, a missing y at each x level, and both missing.
  std::vector<int> exact(static_cast<size_t>(nx) * ny, none);
  std::vector<int> wild_x(ny, none), wild_y(nx, none);
  int wild_xy = none;
  for (R_xlen_t i = 0; i < n; ++i) {
    int x = sx[i], y = sy[i];
    int row = static_cast<int>(i + 1);
    bool xw = x == NA_INTEGER, yw = y == NA_INTEGER;
    if ((!xw && (x < 1 || x > nx)) || (!yw && (y < 1 || y > ny))) continue;
    if (xw && yw) {
      if (wild_xy == none) wild_xy = row;
    } else if (xw) {
      if (wild_x[y - 1] == none) wild_x[y - 1] = row;
    } else if (yw) {
      if (wild_y[x - 1] == none) wild_y[x - 1] = row;
    } else {
      int& e = exact[static_cast<size_t>(y - 1) * nx + (x - 1)];
      if (e == none) e = row;
    }
  }
  R_xlen_t m = cx.size();
  IntegerVector out(m);
  for (R_xlen_t k = 0; k < m; ++k) {
    int x = cx[k], y = cy[k];
    if (x == NA_INTEGER || y == NA_INTEGER || x < 1 || x > nx || y < 1 || y > ny) {
      out[k] = 0;
      continue;
    }
    int e = exact[static_cast<size_t>(y - 1) * nx + (x - 1)];
    int best = e;
    for (int w : {wild_x[y - 1], wild_y[x - 1], wild_xy}) {
      if (w != none && (best == none || w < best)) best = w;
    }
    out[k] = best == none ? 0 : (best == e ? best : -best);
  }
  return out;
}

namespace {

bool plain_list(SEXP node) {
  return TYPEOF(node) == VECSXP && Rf_getAttrib(node, R_ClassSymbol) == R_NilValue;
}

// The first element whose name is exactly `name`, as `$` finds it when an
// exact match exists; -1 when none does.
R_xlen_t name_index(SEXP node, const char* name) {
  SEXP names = Rf_getAttrib(node, R_NamesSymbol);
  if (names == R_NilValue) return -1;
  R_xlen_t n = XLENGTH(names);
  for (R_xlen_t i = 0; i < n; ++i) {
    SEXP s = STRING_ELT(names, i);
    if (s != NA_STRING && std::strcmp(Rf_translateCharUTF8(s), name) == 0) return i;
  }
  return -1;
}

// `node[] <- lapply(node, walk)` on a plain list: a copy only when a child
// changed.
template <typename Walk>
SEXP walk_children(SEXP node, Walk walk) {
  R_xlen_t n = XLENGTH(node);
  SEXP out = node;
  PROTECT_INDEX ipx;
  PROTECT_WITH_INDEX(out, &ipx);
  for (R_xlen_t i = 0; i < n; ++i) {
    SEXP child = VECTOR_ELT(out, i);
    SEXP walked = walk(child);
    if (walked != child) {
      PROTECT(walked);
      if (out == node) REPROTECT(out = Rf_shallow_duplicate(node), ipx);
      SET_VECTOR_ELT(out, i, walked);
      UNPROTECT(1);
    }
  }
  UNPROTECT(1);
  return out;
}

SEXP drop_walk(SEXP node, const Function& fallback) {
  if (TYPEOF(node) == LISTSXP || (TYPEOF(node) == VECSXP && !plain_list(node))) {
    return fallback(node);
  }
  if (TYPEOF(node) != VECSXP) return node;
  R_xlen_t at = name_index(node, "selectors");
  if (at >= 0 && Rf_length(VECTOR_ELT(node, at)) == 0) {
    // `node$selectors <- NULL`: that one element goes, every other
    // attribute stays.
    R_xlen_t n = XLENGTH(node);
    SEXP names = Rf_getAttrib(node, R_NamesSymbol);
    SEXP out = PROTECT(Rf_allocVector(VECSXP, n - 1));
    SEXP out_names = PROTECT(Rf_allocVector(STRSXP, n - 1));
    for (R_xlen_t i = 0, j = 0; i < n; ++i) {
      if (i == at) continue;
      SET_VECTOR_ELT(out, j, VECTOR_ELT(node, i));
      SET_STRING_ELT(out_names, j, STRING_ELT(names, i));
      ++j;
    }
    Rf_copyMostAttrib(node, out);
    Rf_setAttrib(out, R_NamesSymbol, out_names);
    UNPROTECT(2);
    node = out;
  }
  PROTECT(node);
  if (XLENGTH(node) == 0) {
    UNPROTECT(1);
    return node;
  }
  SEXP out = walk_children(node, [&](SEXP child) { return drop_walk(child, fallback); });
  UNPROTECT(1);
  return out;
}

bool selector_string(SEXP entry) {
  return TYPEOF(entry) == STRSXP && XLENGTH(entry) == 1 &&
         STRING_ELT(entry, 0) != NA_STRING && LENGTH(STRING_ELT(entry, 0)) > 0;
}

// join_selector_list() on an unclassed value; NULL when it returns the
// selectors untouched.
SEXP join_selectors(SEXP selectors) {
  std::vector<SEXP> entries;
  if (TYPEOF(selectors) == STRSXP) {
    for (R_xlen_t i = 0; i < XLENGTH(selectors); ++i) {
      SEXP s = STRING_ELT(selectors, i);
      if (s == NA_STRING || LENGTH(s) == 0) return R_NilValue;
      entries.push_back(s);
    }
  } else if (TYPEOF(selectors) == VECSXP &&
             Rf_getAttrib(selectors, R_NamesSymbol) == R_NilValue) {
    for (R_xlen_t i = 0; i < XLENGTH(selectors); ++i) {
      SEXP e = VECTOR_ELT(selectors, i);
      if (!selector_string(e)) return R_NilValue;
      entries.push_back(STRING_ELT(e, 0));
    }
  }
  if (entries.empty()) return R_NilValue;
  std::string joined;
  bool ascii = true;
  for (size_t i = 0; i < entries.size(); ++i) {
    if (i) joined += ", ";
    const char* s = Rf_translateCharUTF8(entries[i]);
    for (const char* p = s; *p; ++p) {
      if (static_cast<unsigned char>(*p) > 127) ascii = false;
    }
    joined += s;
  }
  return Rf_ScalarString(Rf_mkCharLenCE(joined.data(), static_cast<int>(joined.size()),
                                        ascii ? CE_NATIVE : CE_UTF8));
}

SEXP flatten_walk(SEXP node, const std::vector<std::string>& types,
                  const Function& fallback, const Function& join) {
  if (TYPEOF(node) == LISTSXP || (TYPEOF(node) == VECSXP && !plain_list(node))) {
    return fallback(node);
  }
  if (TYPEOF(node) != VECSXP) return node;
  R_xlen_t type_at = name_index(node, "type");
  R_xlen_t sel_at = name_index(node, "selectors");
  int nprot = 0;
  if (type_at >= 0 && sel_at >= 0) {
    SEXP type = VECTOR_ELT(node, type_at);
    bool single = false;
    if (TYPEOF(type) == STRSXP && XLENGTH(type) == 1 && STRING_ELT(type, 0) != NA_STRING) {
      std::string t = Rf_translateCharUTF8(STRING_ELT(type, 0));
      for (const std::string& s : types) single = single || s == t;
    }
    if (single) {
      SEXP selectors = VECTOR_ELT(node, sel_at);
      SEXP joined;
      if (Rf_getAttrib(selectors, R_ClassSymbol) != R_NilValue) {
        joined = PROTECT(join(selectors));
      } else {
        joined = join_selectors(selectors);
        if (joined == R_NilValue) joined = selectors;
        PROTECT(joined);
      }
      ++nprot;
      if (joined != selectors) {
        node = PROTECT(Rf_shallow_duplicate(node));
        ++nprot;
        SET_VECTOR_ELT(node, sel_at, joined);
      }
    }
  }
  if (XLENGTH(node) == 0) {
    UNPROTECT(nprot);
    return node;
  }
  SEXP out = walk_children(node, [&](SEXP child) {
    return flatten_walk(child, types, fallback, join);
  });
  UNPROTECT(nprot);
  return out;
}

}  // namespace

//' drop_empty_selectors() over a whole payload, in C++
//'
//' @param node A maidr-data node.
//' @param fallback [drop_empty_selectors()], for a classed list or a
//'   pairlist, whose `$<-` and `[<-` the R version dispatches on.
//' @return As [drop_empty_selectors()].
//' @keywords internal
//' @noRd
// [[Rcpp::export]]
SEXP drop_empty_selectors_cpp(SEXP node, Function fallback) {
  return drop_walk(node, fallback);
}

//' flatten_single_selectors() over a whole payload, in C++
//'
//' @param node A maidr-data node.
//' @param types `SINGLE_SELECTOR_LAYER_TYPES`.
//' @param fallback [flatten_single_selectors()], for a classed list or a
//'   pairlist.
//' @param join [join_selector_list()], for a classed `selectors`.
//' @return As [flatten_single_selectors()].
//' @keywords internal
//' @noRd
// [[Rcpp::export]]
SEXP flatten_single_selectors_cpp(SEXP node, CharacterVector types, Function fallback,
                                  Function join) {
  std::vector<std::string> t;
  for (R_xlen_t i = 0; i < types.size(); ++i) t.push_back(Rf_translateCharUTF8(types[i]));
  return flatten_walk(node, t, fallback, join);
}
