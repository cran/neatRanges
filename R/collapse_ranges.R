#' Collapses the consecutive date or timestamp ranges into one record.
#'
#' The date/time ranges where the gap between two records is equal to or less than max_gap parameter are collapsed into one record.
#'
#' @param df Your data frame
#' @param groups Grouping variables
#' @param start_var Start of the range
#' @param end_var End of the range
#' @param max_gap Gap between date or timestamp ranges, e.g. for 0, default, it will put together all records where there is no gap in-between
#' @param dimension Indicate whether your range includes only dates ('date') or also timestamp ('timestamp'). Defaults to 'date'
#' @param fmt The format of your date or timestamp field, defaults to YMD
#' @param tz Time zone, defaults to UTC
#' @param origin Origin for timestamp conversion, defaults to 1970-01-01
#'
#' @return Returns a data frame (if initial input data.table, then data.table) with collapsed records.
#'
#' @examples
#' df_collapse <- data.frame(
#' id = c(rep("1111", 3), rep("2222", 3)),
#' rating = c("A+", "AA", "AA", rep("B-", 3)),
#' start_date = c("2014-01-01", "2015-01-01", "2016-01-01",
#'               "2017-01-01", "2018-01-01", "2019-01-01"),
#' end_date = c("2014-12-31", "2015-12-31", "2016-03-01",
#'             "2017-01-31", "2018-12-31", "2020-02-01")
#'             )
#'
#' collapse_ranges(df_collapse, c("id", "rating"), "start_date", "end_date")
#' @export
collapse_ranges <- function(df,
                            groups = NULL,
                            start_var = NULL,
                            end_var = NULL,
                            dimension = "date",
                            max_gap = 0L,
                            fmt = "%Y-%m-%d",
                            tz = "UTC",
                            origin = "1970-01-01") {
  
  max_gap <- max_gap + 1L
  
  cumidx <- "cumidx4"
  
  if (!is.null(groups)) {
    
    group_1stlvl <- groups
    
  }
  
  group_by_args_2lvl <- c(groups, cumidx)
  groupsArrange <- c(groups, start_var)
  
  rangevars <- c(
    start_var,
    end_var
  )
  
  df_collapsed <- copy(df)
  df_collapsed <- setDT(df_collapsed)
  
  if (dimension == "date") {
    
    calc_cummax_Date <- function(x) (setattr(cummax(unclass(x)), "class", c("Date", "IDate")))
    
    df_collapsed <- df_collapsed[
      , (rangevars) := lapply(.SD, function(x) as.Date(as.character(x), format = fmt)), .SDcols = rangevars]
    
    df_collapsed <- df_collapsed[with(df_collapsed, do.call(order, mget(groupsArrange))), ]
    
    if (!is.null(groups)) {
      
      df_collapsed <- df_collapsed[, max_until_now := shift(calc_cummax_Date(get(end_var))), by = mget(group_1stlvl)]
      
    } else {
      
      df_collapsed <- df_collapsed[, max_until_now := shift(calc_cummax_Date(get(end_var)))]
      
    }
    
  } else if (dimension == "timestamp") {
    
    if (fmt == "%Y-%m-%d") {
      
      warning("Dimension 'timestamp' selected but format unchanged. Will try to convert to '%Y-%m-%d %H:%M:%OS' ..")
      
      fmt <- "%Y-%m-%d %H:%M:%OS"
      
    }
    
    calc_cummax_Time <- function(x) {
      
      x <- as.POSIXct(cummax(as.numeric(x)), tz = tz, origin = origin)
      
    }
    
    df_collapsed <- df_collapsed[
      , (rangevars) := lapply(.SD, function(x) as.POSIXct(as.character(x), format = fmt, tz = tz)), .SDcols = rangevars]
    
    df_collapsed <- df_collapsed[with(df_collapsed, do.call(order, mget(groupsArrange))), ]
    
    if (!is.null(groups)) {
      
      df_collapsed <- df_collapsed[, max_until_now := shift(calc_cummax_Time(get(end_var))), by = mget(group_1stlvl)]
      
    } else {
      
      df_collapsed <- df_collapsed[, max_until_now := shift(calc_cummax_Time(get(end_var)))]
      
    }
    
  } else { stop("The dimension argument has to be either 'date' or 'timestamp'.") }
  
  if (!is.null(groups)) {
    
    df_collapsed <- df_collapsed[, lead_max := shift(max_until_now, type = "lead"), by = mget(group_1stlvl)][
      is.na(max_until_now), max_until_now := lead_max, by = mget(group_1stlvl)][
        (max_until_now + max_gap) < get(start_var), gap_between := 1, by = mget(group_1stlvl)][
          is.na(gap_between), gap_between := 0][
            , (cumidx) := cumsum(gap_between), by = mget(group_1stlvl)][
              , setNames(list(min(get(start_var)), max(get(end_var))), rangevars), by = mget(group_by_args_2lvl)][
                , (cumidx) := NULL]
    
  } else {
    
    df_collapsed <- df_collapsed[, lead_max := shift(max_until_now, type = "lead")][
      is.na(max_until_now), max_until_now := lead_max][
        (max_until_now + max_gap) < get(start_var), gap_between := 1][
          is.na(gap_between), gap_between := 0][
            , (cumidx) := cumsum(gap_between)][
              , setNames(list(min(get(start_var)), max(get(end_var))), rangevars), by = mget(group_by_args_2lvl)][
                , (cumidx) := NULL]
    }
  
  if (!any(class(df) %in% "data.table")) {
    
    return(setDF(df_collapsed))
    
  } else {
    
    return(df_collapsed)
    
  }
  
}