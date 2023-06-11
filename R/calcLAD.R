#' @name calcLAD
#' @title Calculate summary statistics from measured leaf inclination angles
#' @param data Dataframe. The dataframe containing leaf inclination angle measurements.
#' @param angles Numeric. The column containing leaf inclination angle measurements (in degrees).
#' @param type Character. If set to "summary", it gives summary distributions. If set to "extended", it calculates LAD probability density (pdf) and G-function (G) for view or inclination angles (theta). Default set to "summary".
#' @param ... The column(s) indicating the grouping variables to be considered for calculating summary statistics.
#'
#' @importFrom dplyr mutate select summarise distinct group_by ungroup left_join n
#' @importFrom rlang .data
#' @importFrom utils data
#' @importFrom purrr map
#' @importFrom stats sd
#' @importFrom tidyr nest unnest unnest_wider

#' @description
#' The function derives summary statistics from measured leaf inclination angles:.
#' * Mean (MTA), standard deviation (SD) and frequency (NR) observations.
#' * The two (mu, nu) Beta parameters derived from the formula provided by Goel and Strebel (1984) \doi{10.2134/agronj1984.00021962007600050021x}.
#' * The distribution type, comparing the distribution against the six theoretical LAD distributions provided by [de Wit (1965)](https://library.wur.nl/WebQuery/wurpubs/413358).
#'
#' @return A dataframe with the grouping variable(s), and:
#' * summary statistics (MTA, SD, N, mu, nu, distribution) in case of type="summary";
#' * LAD (pdf) and G-function (G) in case of type="extended".
#'
#' @examples
#' head(Chianucci)
#' \donttest{
#' calcLAD(Chianucci,Angle_degree,type='summary',Genus,Species)
#' calcLAD(Chianucci,Angle_degree,type='extended',Genus,Species)
#' }
#'
#' @export

utils::globalVariables(c('.','data','distribution'))

calcLAD<-function(.data,.angles,type='summary',...){
  options(dplyr.summarise.inform = FALSE)

  if(type!='summary'&type!='extended'){
    stop('You can select "summary" for summary distribution or "extended" for full statistics')
  }

  rad=pi/180
  angles<-deparse(substitute(.angles))
  # group<-deparse(substitute(...))

  if (min(.data[[angles]]) < 0 | max(.data[[angles]]) > 90){
    stop ('measured leaf inclination angle should be measured in degrees and range between 0 and 90. Check your data!')
  }

  if (max(.data[[angles]]) <= 2*pi){
    warning ('Low inclination angle values - are you sure the measured unit is degrees?')
  }


  dataset<- .data %>%
    # group_by(.data[[group]]) %>%
    dplyr::group_by(...) %>%
    dplyr::summarise(MTA=round(mean(.data[[angles]]),1),SD=round(stats::sd(.data[[angles]]),2),N=dplyr::n())

  dataset2<-.data %>%
    # group_by(.data[[group]]) %>%
    dplyr::group_by(...) %>%
    dplyr::mutate(t=2*(.data[[angles]]*rad)/pi) %>%
    dplyr::summarise(tm=mean(.data$t),var=stats::sd(.data$t)^2,s0=.data$tm*(1-.data$tm),k=((.data$s0/.data$var)-1),mu=round(((1-.data$tm)*.data$k),2),nu=round(.data$tm*.data$k,2) ) %>%
    dplyr::select(...,.data$mu,.data$nu)

  if (type=='summary'){
  dataset3<-dataset2 %>%
    dplyr::group_by(...) %>%
    tidyr::nest() %>%
    dplyr::mutate(distr=purrr::map(data,~fitLAD(.x$mu,.x$nu))) %>%
    tidyr::unnest_wider(.data$distr) %>%
    dplyr::distinct(...,distribution=distribution$distribution) %>%
    dplyr::ungroup()}

  if(type=='extended'){
    dataset3<-dataset2 %>%
      dplyr::group_by(...) %>%
      tidyr::nest() %>%
      dplyr::mutate(distr=purrr::map(data,~fitLAD(.x$mu,.x$nu))) %>%
      tidyr::unnest_wider(.data$distr) %>%
      tidyr::unnest(.data$dataset) %>%
      dplyr::ungroup()
  }


if (type=='summary'){
  out<-dataset %>%
    dplyr::left_join(dataset2) %>%
    dplyr::left_join(dataset3) %>%
    dplyr::ungroup()}

if (type=='extended'){
  out<-dataset3 %>%
    dplyr::select(...,.data$theta,.data$pdf,.data$G)
}


  return(out)

}

