#' @title
#' Class: ArrayEnvironment
#'
#' @description
#' Class representing arrays.
#'    
#' @field .array \code{\link{environment}}.
#'  Environment that serves as an array container.
#' @example inst/examples/ArrayEnvironment.r
#' @template author
#' @template references
#' @import conditionr
#' @import R6
#' @export
ArrayEnvironment <- R6Class(
  classname = "ArrayEnvironment",
  portable = TRUE,
  public = list(
    .array = "environment",
    initialize = function(...) {
      self$.array <- new.env(parent = emptyenv())
      value <<- list(...)
      value_length <- length(value)
      if (value_length > 0)  {
        if (value_length == 1 && is.null(names(value))) {
          value <- value[[1]]
        } else if (value_length >= 2 && is.null(names(value))) {
          value <- unlist(value,recursive = FALSE)
        }        
        self$.set(value)
      }
    },
    .autoadjustNumericKeys = function(nms = NULL, id) {
      nms <- self$.order(all_names = TRUE)
      if (!is.null(nms)) {
        idx_num <- grepl("^\\d*$", nms)
        if (any(idx_num)) {
          tmp <- nms[idx_num]
          sapply(seq(along = tmp), function(ii) {
            from <- as.character(tmp[ii])
            to <- as.character(ii)
            if (from != to) {
              assign(to, self$get(from), envir = self$.array)    
              rm(list = from, envir = self$.array, inherits = FALSE)
            }
          })
        }
        TRUE
      } else {
        FALSE
      }
    },
    .getNumericKeys = function() {
      nms <- self$.order(all_names = TRUE)
      idx_num <- grepl("^\\d*$", nms)
      if (length(idx_num)) {
        nms[idx_num]
      } else {
        nms
      }
    },
    .indexNumericKeys = function(sorted = TRUE, all_names = FALSE) {
      nms <- if (sorted) {
        self$.order(all_names = all_names)
      } else {
        ls(self$.array, all.names = all_names)
      }
      grep("^\\d*$", nms)
    },
    .set = function(value, intnum = TRUE) {
      if (inherits(value, "environment")) {
        value <- list(value)
      }
      if (inherits(value, "data.frame")) {
        value <- list(value)
      }
      sapply(seq(along = value), function(ii) {
        name <- names(value[ii])
        value <- value[[ii]]
        if (is.null(name) || name == "") {
          .names <- ls(self$.array, all.names = TRUE)
          .nums <- grep("^\\d*$", .names, value = TRUE)
          name <- if (length(.nums)) {
            as.character(max(sort(as.numeric(.nums))) + 1)
          } else {
            "1"
          }
        }      
        if (inherits(value, "integer") && intnum) {
          value <- as.numeric(value)
        }
        assign(name, value, envir = self$.array)  
        structure(TRUE, names = name)
      })
    },
    apply = function(x, fun, ...) {
      lapply(self$get(x, ...), fun, ...)
    },
    mapReduce = function(x, fun, ...) {
      warning("This method is just an experiment; do not depend on it!")
      fun(unlist(self$get(x, ...)), ...)
    },
    add = function(..., id = character(), must_exist = FALSE, 
      overwrite = TRUE, strict = 0) {      
      
      id <- as.character(id)
      value <- list(...)    
      if (!length(id)) {
        nms <- ls(self$.array, all.names = TRUE)
        out <- unlist(lapply(seq(along = value), function(ii) {
          name <- names(value[ii])
          value <- value[[ii]]
          if (!is.null(name)) {
            value <- structure(list(value), names = name)
          }
          has_non <- must_exist && !all(idx_non <- names(value) %in% nms)
          has_existing <- !overwrite && any(idx_dups <- names(value) %in% nms)
          out <- if (has_non || has_existing) {      
            if (has_non) {
              msg <- c(
                Reason = "no such element",
                IDs = names(value)[which(!idx_non)]
              )
            }
            if (has_existing) {
              msg <- c(
                Reason = "element already exists",
                IDs = names(value)[which(idx_dups)]
              )
            }
            if (strict == 0) { 
              structure(FALSE, names = names(value))
            } else if (strict == 1) {
              conditionr::signalCondition(
                condition = "Invalid",
                msg = msg,
                ns = "ArrayEnvironment",
                type = "warning"
              )  
              structure(FALSE, names = names(value))
            } else if (strict == 2) {
              conditionr::signalCondition(
                condition = "Invalid",
                msg = msg,
                ns = "ArrayEnvironment",
                type = "error"
              )
            }
          } else {
            self$.set(value)
#             if (inherits(value, "environment")) {
#               structure(rep(TRUE, 1), names = names(value))
#             } else {         
#               structure(rep(TRUE, length(value)), names = names(value))
#             }
          }
          out
        }))
      } else {
        out <- if (length(value) != length(id)) {
          if (strict == 0) {
            FALSE
          } else if (strict == 1) {
            conditionr::signalCondition(
              condition = "Invalid",
              msg = c(
                Reason = "lengths differ",
                "Length `value`" = length(value),
                "Length `id`" = length(id)
              ),
              ns = "ArrayEnvironment",
              type = "warning"
            )  
            FALSE
          } else if (strict == 2) {
            conditionr::signalCondition(
              condition = "Invalid",
              msg = c(
                Reason = "lengths differ",
                "Length `value`" = length(value),
                "Length `id`" = length(id)
              ),
              ns = "ArrayEnvironment",
              type = "error"
            )
          }
        } else {
          TRUE
        }
        if (out) {
          nms <- ls(self$.array, all.names = TRUE)
          out <- sapply(seq(along = value), function(ii) {
            value <- list(value[[ii]])
            names(value) <- id[[ii]]
            
            has_non <- must_exist && !all(idx_non <- id[[ii]] %in% nms)
            has_existing <- !overwrite && any(idx_dups <- id[[ii]] %in% nms)
            if (has_existing || has_non) {
              if (has_non) {
                msg <- c(
                  Reason = "no such element",
                  IDs = id[[ii]][which(!idx_non)]
                )
              }
              if (has_existing) {
                msg <- c(
                  Reason = "element already exists",
                  IDs = id[[ii]][which(idx_dups)]
                )
              }
              out <- if (strict == 0) {
                structure(FALSE, names = id[[ii]])
              } else if (strict == 1) {
                conditionr::signalCondition(
                  condition = "Invalid",
                  msg = msg,
                  ns = "ArrayEnvironment",
                  type = "warning"
                )  
                structure(FALSE, names = id[[ii]])
              } else if (strict == 2) {
                conditionr::signalCondition(
                  condition = "Invalid",
                  msg = msg,
                  ns = "ArrayEnvironment",
                  type = "error"
                )
              }
            } else {
              self$.set(value)
              structure(rep(TRUE, length(value)), names = names(value))
            }
          })
        }
        out
      }
      out
    },
    copy = function(from, to, all_names = FALSE, char = FALSE, 
      overwrite = FALSE, sorted = FALSE, strict = 0) {
      
#       from <- as.character(from)
      from <- if (inherits(from, c("numeric", "integer")) && !char) {
        from
      } else {
        as.character(from)  
      }
#       to <- as.character(to)
      to <- if (inherits(to, c("numeric", "integer")) && !char) {
        to
      } else {
        as.character(to)  
      }
      
      length_diff <- length(from) != length(to) 
      nms <- if (sorted) {
        self$.order(all_names = all_names)
      } else {
        ls(self$.array, all.names = all_names)
      }
      has_existing <- !overwrite && any(idx_dups <- to %in% nms)
        
      out <- if (length_diff || has_existing) {
      if (length_diff) {
          msg = c(
            Reason = "lengths differ",
            "Length `from`" = length(from),
            "Length `to`" = length(to)
          )
        }
        if (has_existing) {
          msg = c(
            Reason = "element already exists",
            Duplicates = paste(to[idx_dups], collapse = ", ")
          )
        }
        if (strict == 0) {
          structure(rep(FALSE, length(from)), names = from)
        } else if (strict == 1) {
          conditionr::signalCondition(
            condition = "InvalidConstellation",
            msg = msg,
            ns = "ArrayEnvironment",
            type = "warning"
          )
          structure(rep(FALSE, length(from)), names = from)
        } else if (strict == 2) {
          conditionr::signalCondition(
            condition = "InvalidConstellation",
            msg = msg,
            ns = "ArrayEnvironment",
            type = "error"
          )
        }
      } else {
        structure(rep(TRUE, length(from)), names = from)
      }
      if (all(out)) {
        from_to <- list(from = from, to = to)
        out <- sapply(seq(along = from), function(ii) {
          from <- from_to$from[[ii]]
          to <- from_to$to[[ii]]
          out <- if (self$exists(from)) {
            self$add(self$get(from), id = to)
            TRUE
          } else {
            out <- if (strict == 0) {
              FALSE
            } else if (strict == 1) {
              conditionr::signalCondition(
                condition = "Invalid",
                msg = c(
                  Reason = "Invalid ID",
                  ID = from
                ),
                ns = "ArrayEnvironment",
                type = "warning"
              )
              FALSE
            } else if (strict == 2) {
              conditionr::signalCondition(
                condition = "Invalid",
                msg = c(
                  Reason = "Invalid ID",
                  ID = from
                ),
                ns = "ArrayEnvironment",
                type = "error"
              )
            }
          }
        })
        names(out) <- from
      }
      out
    },
    clear = function() {
      rm(list = ls(self$.array, all.names = TRUE), envir = self$.array)
      TRUE
    },
#     exists = function(id) {
    exists = function(..., char = FALSE) {
      id <- unlist(list(...))
      ## Index object type //
      out <- if (inherits(id, c("numeric", "integer")) && !char) {
        scope <- 1:length(self$.array)
        structure(id %in% scope, names = id)
      } else {
        id <- as.character(id)  
        sapply(id, function(ii) {
          exists(ii, envir = self$.array, inherits = FALSE)
        })
      }
      out
    },
    
#     get = function(id = character(), all_names = FALSE, char = FALSE, 
    get = function(..., all_names = FALSE, char = FALSE,                    
      default = NULL, inner = TRUE, list = FALSE,  
      simplify = TRUE, sorted = TRUE, strict = 0) {
      
      id <- unlist(list(...))
      ## Index object type //
      if (inherits(id, c("numeric", "integer")) && !char) {
        nms <- if (sorted) {
          self$.order(all_names = all_names)
        } else {
          ls(self$.array, all.names = all_names)
        }
        id <- nms[id]
        if (length(id)) {
          id <- if (any(is.na(id))) idx[-which(is.na(id))] else id
        }
      } else {
        id <- as.character(id)  
      }
      out <- if (strict > 0 && 
        !all(idx <- id %in% ls(self$.array, all.names = TRUE))) {
        
        if (strict == 0) {
          TRUE
        } else if (strict == 1) {
          conditionr::signalCondition(
            condition = "Invalid",
            msg = c(
              Reason = "invalid ID(s)",
              IDs = id[!idx]
            ),
            ns = "ArrayEnvironment",
            type = "warning"
          )  
          TRUE
        } else if (strict == 2) {
          conditionr::signalCondition(
            condition = "Invalid",
            msg = c(
              Reason = "invalid ID(s)",
              IDs = id[!idx]
            ),
            ns = "ArrayEnvironment",
            type = "error"
          )
        }
      } else {
        TRUE
      }
      out <- if (out) {
        if (length(id)) {
          out <- lapply(id, function(ii) {
#             out <- get(ii, envir = self$.array, inherits = FALSE)
            this <- as.list(self$.array)
            out <- if (inner) this[[ii]] else this[ii]
            if (!is.null(names(out)) && all(is.na(names(out)))) {
              out <- if (inner) default else structure(list(default), names = ii)
            }
            out
          })
          names(out) <- id
          if (length(id) == 1 && length(out) == 1) {
            out <- out[[1]]
          }
          out
        } else {
          if (list) {
            if (sorted) {
              inst$.sort(all_names = TRUE)
            } else {
              nms <- ls(self$.array, all.names = all_names)
              as.list(self$.array, all.names = all_names)[nms]
            }
          } else {
            self$.array
          }
        }
      } else {
        default
      }
      out
    },
#     index = function(id, all_names = FALSE, simplify = FALSE, strict = 0) {
    index = function(..., all_names = FALSE, simplify = FALSE, strict = 0) {
#       id <- as.character(id)
      id <- as.character(unlist(list(...)))
      idx <- sort(id) %in% sort(ls(self$.array, all.names = all_names))
      out <- if (strict > 0 && !all(idx)) {
        if (strict == 0) {
          idx
        } else if (strict == 1) {
          conditionr::signalCondition(
            condition = "Invalid",
            msg = c(
              Reason = "invalid ID(s)",
              IDs = id[!idx]
            ),
            ns = "ArrayEnvironment",
            type = "warning"
          )  
          idx
        } else if (strict == 2) {
          conditionr::signalCondition(
            condition = "Invalid",
            msg = c(
              Reason = "invalid ID(s)",
              IDs = id[!idx]
            ),
            ns = "ArrayEnvironment",
            type = "error"
          )
        }
      } else {
        idx
      }
#       if (any(out)) {
        out <- rep(NA_integer_, length(id))
        val <- as.numeric(
          which(sort(ls(self$.array, all.names = TRUE)) %in% sort(id))
        )
        if (length(val)) {
          out[idx] <- val
        }
        names(out) <- sort(id)
        if (any(!idx) && simplify) {
          out <- as.numeric(out[-which(is.na(out))])
        }
#       }  
        out
    },
    .order = function(all_names = FALSE) {
      nms <- ls(self$.array, all.names = all_names)
      idx <- grepl("^\\d*$", nms)
      if (length(idx)) {
        nms <- if (any(idx)) {
          c(sort(as.numeric(nms[idx])), sort(nms[!idx]))
        } else {
          sort(nms)
        }
      }
      nms
    },
    rm = function(..., all_names = FALSE, numonly = TRUE, 
      sorted = TRUE, strict = 0) {
      
      id <<- unlist(list(...))
      if (inherits(id, c("numeric", "integer"))) {
        nms <- if (sorted || numonly) {
          self$.order(all_names = all_names)
        } else {
          ls(self$.array, all.names = all_names)
        }
        if (numonly) {
          nms <- self$.getNumericKeys() 
          id <- nms[nms %in% id]
        } else {
          id <- nms[id]  
        }
        if (length(id)) {
          id <- if (any(is.na(id))) idx[-which(is.na(id))] else id
        }
      } else {
        nms <- NULL
        id <- as.character(id)  
      }
      idx <- sapply(id, exists, envir = self$.array, inherits = FALSE)
      out <- if (!any(idx)) {       
        if (strict == 0) {
          FALSE
        } else if (strict == 1) {
          conditionr::signalCondition(
            condition = "Invalid",
            msg = c(
              Reason = "invalid ID",
              IDs = paste(id[!idx], collapse = ", ")
            ),
            ns = "ArrayEnvironment",
            type = "warning"
          )
          FALSE
        } else if (strict == 2) {
          conditionr::signalCondition(
            condition = "Invalid",
            msg = c(
              Reason = "invalid ID",
              IDs = paste(id[!idx], collapse = ", ")
            ),
            ns = "ArrayEnvironment",
            type = "error"
          )
        }
      } else {
        TRUE
      }   
      if (out) {
        rm(list = id[idx], envir = self$.array, inherits = FALSE)
        self$.autoadjustNumericKeys(nms = nms, id = id)
      } 
      out <- idx
      out
    },
    rmFirst = function(n = 1, strict = 0, simplify = FALSE) {
      scope <- length(self$.array)
      out <- if (n > scope) {
        if (strict == 0) {
          out <- structure(rep(FALSE, n), names = 1:n)
          out[1:scope] <- TRUE
          out
        } else if (strict == 1) {
          conditionr::signalCondition(
            condition = "Invalid",
            msg = c(
              Reason = "invalid scope",
              Scope = n,
              Length = scope
            ),
            ns = "ArrayEnvironment",
            type = "warning"
          )
          out <- structure(rep(FALSE, n), names = 1:n)
          out[1:scope] <- TRUE
          out
        } else if (strict == 2) {
          conditionr::signalCondition(
            condition = "Invalid",
            msg = c(
              Reason = "invalid scope",
              Scope = n,
              Length = scope
            ),
            ns = "ArrayEnvironment",
            type = "error"
          )
        }
      } else {
        out <- structure(rep(TRUE, n), names = 1:n)
      }
      nms <- ls(self$.array, all.names = TRUE)
      idx <- grepl("^\\d*$", nms)
      if (length(idx)) {
        nms <- if (any(idx)) {
          c(sort(as.numeric(nms[idx])), sort(nms[!idx]))
        } else {
          sort(nms)
        }
        rm(list = nms[1:min(n, scope)], envir = self$.array)
      }
      if (simplify) {
        out <- all(out)
      } 
      out
    },
    rmLast = function(n = 1, strict = 0, simplify = FALSE) {
      scope <- length(self$.array)
      out <- if (n > scope || scope == 0) {
        if (strict == 0) {
          out <- structure(rep(FALSE, n), names = scope:(scope - (n - 1)))
          if (scope > 0) {
            out[1:scope] <- TRUE
          }
          out
        } else if (strict == 1) {
          conditionr::signalCondition(
            condition = "InvalidScope",
            msg = c(
              Reason = "invalid scope",
              Scope = n,
              Length = scope
            ),
            ns = "ArrayEnvironment",
            type = "warning"
          )
          out <- structure(rep(FALSE, n), names = scope:(scope - (n - 1)))
          if (scope > 0) {
            out[1:scope] <- TRUE
          }
          out
        } else if (strict == 2) {
          conditionr::signalCondition(
            condition = "InvalidScope",
            msg = c(
              Reason = "invalid scope",
              Scope = n,
              Length = scope
            ),
            ns = "ArrayEnvironment",
            type = "error"
          )
        }
      } else {
        out <- structure(rep(TRUE, n), names = scope:(scope - (n - 1)))
      }
      nms <- ls(self$.array, all.names = TRUE)
      idx <- grepl("^\\d*$", nms)
      if (length(idx)) {
        nms <- if (any(idx)) {
          c(sort(as.numeric(nms[idx])), sort(nms[!idx]))
        } else {
          sort(nms)
        }
        rm(list = nms[(max((scope - (n-1)), 1):scope)], envir = self$.array)
      }
      if (simplify) {
        out <- all(out)
      } 
      out
    },
    .sort = function(all_names = FALSE) {
      idx <- self$.order(all_names = all_names)
      as.list(self$.array, all.names = all_names)[idx]
    },
    set = function(..., id = character(), must_exist = TRUE, 
      overwrite = TRUE, strict = 0) {      
      self$add(..., id = id, must_exist = must_exist, 
        overwrite = overwrite, strict = strict)
    }
  )
)


