# Rscript jd.R <a.rds> <b.rds> : show differing leaves of maidr-data
args <- commandArgs(TRUE)
a <- jsonlite::fromJSON(readRDS(args[1])$maidr, simplifyVector = FALSE); b <- jsonlite::fromJSON(readRDS(args[2])$maidr, simplifyVector = FALSE)
fa <- unlist(a); fb <- unlist(b)
fa <- fa[!grepl("id$", names(fa))]; fb <- fb[!grepl("id$", names(fb))]
k <- union(names(fa), names(fb))
for (n in k) if (!identical(unname(fa[n]), unname(fb[n]))) cat(n, ": head=", fa[n], " main=", fb[n], "\n")
