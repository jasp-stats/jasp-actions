#  Drop "stop" "warning" "message" "packageStartupMessage" in xgettext.
#  Modified from R-SVN File src/library/tools/R/xgettext.R and translation.R
#  Snapshot at UTC+8 2022-11-14 12:00


if(!exists("rootfolder"))
{
	args <- commandArgs(trailingOnly = TRUE)
	
	if (length(args)!=1) {
	  stop("Give the root folder of the package or the root of the R-code of JASP")
	} else {
	  rootfolder<- args[1]
	}
}

Sys.setlocale(category = "LC_ALL", locale = "en_US.UTF-8")


#  Start of copied code from R-SVN File src/library/tools/R/xgettext.R
#  Refactoring xgettext -> jaspXgettext, access tools internal functions.
jaspXgettext <-
  function(dir, verbose = FALSE, asCall = TRUE)
  {
    dir <- tools:::file_path_as_absolute(dir)
    bn <- basename(dir)
    dir <- file.path(dir, "R")
    exts <- tools:::.make_file_exts("code")
    R_files <- tools:::list_files_with_exts(dir, exts)
    for(d in c("unix", "windows")) {
      OSdir <- file.path(dir, d)
      if(dir.exists(OSdir))
        R_files <- c(R_files, tools:::list_files_with_exts(OSdir, exts))
    }
    if(bn == "base") {
      ## include loader files in R_HOME/share/R
      shdir <- file.path(dir, "../../../../share/R")
      R_files <- c(R_files, tools:::list_files_with_exts(shdir, exts))
    }
    out <- vector("list", length = length(R_files))
    names(out) <- R_files

    find_strings <- function(e) {
      find_strings2 <- function(e, suppress) {
        if(is.character(e)) {
          if(!suppress) strings <<- c(strings, e)
        } else if(is.call(e)) {
          if(is.name(e[[1L]])
             && (as.character(e[[1L]]) %in% c("gettext", "gettextf"))) {
            domain <- e[["domain"]]
            suppress <- !is.null(domain) && !is.name(domain) && is.na(domain)
            if(as.character(e[[1L]]) == "gettextf") {
              e <- match.call(gettextf, e)
              e <- e["fmt"] # just look at fmt arg
            } else if(as.character(e[[1L]]) == "gettext" &&
                      !is.null(names(e))) {
              e <- e[!(names(e) == "domain")] # remove domain arg
            }
          } else if (identical(e[[1L]], quote(ngettext)))
            return()
          for(i in seq_along(e)) find_strings2(e[[i]], suppress)
        }
      }
      if(is.call(e)
         && is.name(e[[1L]])
         && (as.character(e[[1L]])
             %in% c(
               # Once we want to translate the strings in these calls, enable these：
               # "warning",
               # "stop",
               # "message",
               # "packageStartupMessage",
               "gettext",
               "gettextf"))) {
        domain <- e[["domain"]]
        suppress <- !is.null(domain) && !is.name(domain) && is.na(domain)
        ## remove named args
        `%notin%` <- Negate(`%in%`)
        if(!is.null(names(e)))
          e <- e[names(e) %notin% c("call.", "immediate.", "domain")]
        if(asCall) {
          if(!suppress) strings <<- c(strings, as.character(e)[-1L])
        } else {
          if(as.character(e[[1L]]) == "gettextf") {
            e <- match.call(gettextf, e)
            e <- e["fmt"] # just look at fmt arg
          }
          for(i in seq_along(e)) find_strings2(e[[i]], suppress)
        }
      } else if(is.recursive(e))
        for(i in seq_along(e)) Recall(e[[i]])
    }

    for(f in R_files) {
      if(verbose) message(gettextf("parsing '%s'", f), domain = NA)
      strings <- character()
      for(e in parse(file = f)) find_strings(e)
      ## strip leading and trailing white space
      strings <- sub("^[ \t\n]*", "", strings)
      strings <- sub("[ \t\n]*$", "", strings)
      out[[f]] <- structure(unique(strings), class="xgettext")
    }

    out[lengths(out) > 0L]
  }


jaspXgettext2pot <-
  function(dir, potFile, name = "R", version, bugs)
  {
    dir <- tools:::file_path_as_absolute(dir)
    if(missing(potFile))
      potFile <- paste0("R-", basename(dir), ".pot")
    msgid <- unique(unlist(jaspXgettext(dir, asCall = FALSE)))
    msgid <- msgid[nzchar(msgid)]
    if(length(msgid) > 0L)
      msgid <- shQuote(encodeString(msgid), type="cmd")  # need to quote \n, \t etc
    msgid_plural <- tools:::xngettext(dir)
    un <- unique(unlist(msgid_plural))

    con <- file(potFile, "wt")
    on.exit(close(con))
    if(missing(version))
      version <- paste(R.version$major, R.version$minor, sep = ".")
    if(missing(bugs)) bugs <- "bugs.r-project.org"
    writeLines(con = con,
               c('msgid ""',
                 'msgstr ""',
                 sprintf('"Project-Id-Version: %s %s\\n"', name, version),
                 sprintf('"Report-Msgid-Bugs-To: %s\\n"', bugs),
                 paste0('"POT-Creation-Date: ',
                        format(Sys.time(), "%Y-%m-%d %H:%M"), # %z is not portable
                        '\\n"'),
                 '"PO-Revision-Date: YEAR-MO-DA HO:MI+ZONE\\n"',
                 '"Last-Translator: FULL NAME <EMAIL@ADDRESS>\\n"',
                 '"Language-Team: LANGUAGE <LL@li.org>\\n"',
                 '"Language: \\n"',
                 '"MIME-Version: 1.0\\n"',
                 '"Content-Type: text/plain; charset=CHARSET\\n"',
                 '"Content-Transfer-Encoding: 8bit\\n"',
                 if (length(un)) '"Plural-Forms: nplurals=INTEGER; plural=EXPRESSION;\\n"'))
    for(e in msgid)
      writeLines(con=con, c('', paste('msgid', e), 'msgstr ""'))
    for(ee in msgid_plural)
      for(e in ee)
        if(e[1L] %in% un) {
          writeLines(
            con=con,
            c('',
              paste('msgid       ', shQuote(encodeString(e[1L]), type="cmd")),
              paste('msgid_plural', shQuote(encodeString(e[2L]), type="cmd")),
              'msgstr[0]    ""',
              'msgstr[1]    ""')
          )
          un <- un[-match(e, un)]
        }
  }
#  End of copied code from xgettext.R

#  Start of copied code from R-SVN File src/library/tools/R/translations.R;
#  Refactoring update_pkg_po -> jasp_update_pkg_po.
jasp_update_pkg_po <- function(pkgdir, pkg = NULL, version = NULL,
                          mergeOpts = "", # only those *in addition* to --update
                          copyright, bugs)
{
    same <- function(a, b)
    {
        tmpa <- readLines(a); tmpb <- readLines(b)
        tmpa <- tools:::filtergrep('^"POT-Creation-Date:', tmpa)
        tmpb <- tools:::filtergrep('^"POT-Creation-Date:', tmpb)
        identical(tmpa, tmpb)
    }

    ## Follow previous version by always collating in C.
    pwd <- getwd()
    coll <-  Sys.getlocale("LC_COLLATE")
    on.exit({Sys.setlocale("LC_COLLATE", coll); setwd(pwd)})
    Sys.setlocale("LC_COLLATE", "C")
    setwd(pkgdir)
    dir.create("po", FALSE)
    files <- dir("po")

    desc <- "DESCRIPTION"
    if(file.exists(desc)) {
        desc <- read.dcf(desc, fields = c("Package", "Version"))
        pkg <- name <- desc[1L]
        version <- desc[2L]
        if (missing(copyright)) copyright <- NULL
        if (missing(bugs)) bugs <- NULL
        stem <- file.path("inst", "po")
    } else { # A base package
        pkg <- basename(pkgdir)
        name <- "R"
        version <- as.character(getRversion())
        copyright <- "The R Core Team"
        bugs <- "bugs.r-project.org"
        stem <- file.path("..", "translations", "inst")
    }

    ## The interpreter is 'src' for the base package.
    is_base <- (pkg == "base")
    have_src <- paste0(pkg, ".pot") %in% files

    ## do R-pkg domain first
    ofile <- tempfile()
    jaspXgettext2pot(".", ofile, name, version, bugs)
    potfile <- file.path("po", paste0("R-", pkg, ".pot"))
    if(file.exists(potfile) && same(potfile, ofile)) {
    } else file.copy(ofile, potfile, overwrite = TRUE)
    pofiles <- dir("po", pattern = "R-.*[.]po$", full.names = TRUE)
    pofiles <- pofiles[pofiles != "po/R-en@quot.po"]
    ## .po file might be newer than .mo
    for (f in pofiles) {
        lang <- sub("^R-(.*)[.]po$", "\\1", basename(f))
        message("  R-", lang, ":", appendLF = FALSE, domain = NA)
        ## This seems not to update the file dates.
        cmd <- paste("msgmerge --update", mergeOpts, f, shQuote(potfile))
        if(system(cmd) != 0L) {
            warning("running msgmerge on ", sQuote(f), " failed", domain = NA)
            next
        }
        res <- tools:::checkPoFile(f, TRUE)
        if(nrow(res)) {
            print(res)
            message("not installing", domain = NA)
            next
        }
        dest <- file.path(stem, lang, "LC_MESSAGES")
        dir.create(dest, FALSE, TRUE)
        dest <- file.path(dest, sprintf("R-%s.mo", pkg))
 #       if(file_test("-ot", f, dest)) next
        cmd <- paste("msgfmt -c --statistics -o", shQuote(dest), shQuote(f))
        if(system(cmd) != 0L)
            warning(sprintf("running msgfmt on %s failed", basename(f)),
                    domain = NA, immediate. = TRUE)
    }

    ## do en@quot
    if (l10n_info()[["UTF-8"]]) {
        lang <- "en@quot"
        message("  R-", lang, ":", domain = NA)
        # f <- "po/R-en@quot.po"
        f <- tempfile()
        tools:::en_quote(potfile, f)
        dest <- file.path(stem, lang, "LC_MESSAGES")
        dir.create(dest, FALSE, TRUE)
        dest <- file.path(dest, sprintf("R-%s.mo", pkg))
        cmd <- paste("msgfmt -c --statistics -o", shQuote(dest), shQuote(f))
        if(system(cmd) != 0L)
            warning(sprintf("running msgfmt on %s failed", basename(f)),
                    domain = NA, immediate. = TRUE)
    }

    if(!(is_base || have_src)) return(invisible())

    ofile <- tempfile()
    if (!is_base) {
        dom <- pkg
        od <- setwd("src")
        exts <- "[.](c|cc|cpp|m|mm)$"
        cfiles <- dir(".", pattern = exts)
        for (subdir in c("windows", "cairo")) { # only grDevices/src/cairo
          if(dir.exists(subdir))
            cfiles <- c(cfiles,
                        dir(subdir, pattern = exts, full.names = TRUE))
        }
    } else {
        dom <- "R"
        od <- setwd("../../..")
        cfiles <- tools:::filtergrep("^#", readLines("po/POTFILES"))
    }
    cmd <- sprintf("jaspXgettext --keyword=_ --keyword=N_ -o %s", shQuote(ofile))
    cmd <- c(cmd, paste0("--package-name=", name),
             paste0("--package-version=", version),
             "--add-comments=TRANSLATORS:",
             if(!is.null(copyright))
                 sprintf('--copyright-holder="%s"', copyright),
             if(!is.null(bugs))
                 sprintf('--msgid-bugs-address="%s"', bugs),
             if(is_base) "-C") # avoid messages about .y
    cmd <- paste(c(cmd, cfiles), collapse=" ")
    if(system(cmd) != 0L) stop("running jaspXgettext failed", domain = NA)
    setwd(od)

    ## compare ofile and po/dom.pot, ignoring dates.
    potfile <- file.path("po", paste0(dom, ".pot"))
    if(!same(potfile, ofile)) file.copy(ofile, potfile, overwrite = TRUE)
    pofiles <- dir("po", pattern = "^[^R].*[.]po$", full.names = TRUE)
    pofiles <- pofiles[pofiles != "po/en@quot.po"]
    for (f in pofiles) {
        lang <- sub("[.]po", "", basename(f))
        message("  ", lang, ":", appendLF = FALSE, domain = NA)
        cmd <- paste("msgmerge --update", mergeOpts, shQuote(f), shQuote(potfile))
        if(system(cmd) != 0L) {
            warning("running msgmerge on ",  f, " failed", domain = NA)
            next
        }
        res <- tools:::checkPoFile(f, TRUE)
        if(nrow(res)) {
            print(res)
            message("not installing", domain = NA)
            next
        }
        dest <- file.path(stem, lang, "LC_MESSAGES")
        dir.create(dest, FALSE, TRUE)
        dest <- file.path(dest, sprintf("%s.mo", dom))
#        if(file_test("-ot", f, dest)) next
        cmd <- paste("msgfmt -c --statistics -o", shQuote(dest), shQuote(f))
        if(system(cmd) != 0L)
            warning(sprintf("running msgfmt on %s failed", basename(f)),
                    domain = NA)
    }
    ## do en@quot
    if (l10n_info()[["UTF-8"]]) {
        lang <- "en@quot"
        message("  ", lang, ":", domain = NA)
        f <- tempfile()
        tools:::en_quote(potfile, f)
        dest <- file.path(stem, lang, "LC_MESSAGES")
        dir.create(dest, FALSE, TRUE)
        dest <- file.path(dest, sprintf("%s.mo", dom))
        cmd <- paste("msgfmt -c --statistics -o", shQuote(dest), shQuote(f))
        if(system(cmd) != 0L)
            warning(sprintf("running msgfmt on %s failed", basename(f)),
                    domain = NA)
    }

    invisible()
}
#  End of copied code from translations.R

try(jasp_update_pkg_po(rootfolder))
