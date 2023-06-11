#' @name fitLAD
#' @title Fit Leaf Angle Distribution (LAD) from two-parameters (mu, nu) Beta distribution
#' @param mu Numeric. The mu parameter of the Beta distribution.
#' @param nu Numeric. The nu parameter of the Beta distribution.
#' @param plot Logical. If set to TRUE, it plots the measured and theoretical LAD and G distributions. Default set to FALSE.
#'
#' @importFrom dplyr mutate select summarize bind_cols
#' @importFrom rlang .data
#' @importFrom tidyselect starts_with
#' @importFrom ggplot2 labs geom_line theme_minimal scale_colour_manual xlab ylab theme ggtitle
#' @importFrom tidyr pivot_longer
#' @importFrom cowplot plot_grid

#' @description
#' The function derives both the Leaf Angle Distribution (LAD) and the G-function from two-parameters (mu, nu) Beta distribution.
#' * The LAD function is fitted through a Beta distribution as recommended by [Goel and Strebel (1984)](<doi:10.2134/agronj1984.00021962007600050021x>).
#' * The G-function is derived from LAD using the formula provided by [Ross (1981)](<doi:10.1007/978-94-009-8647-3>) and reported as Equations 2-3 by [Chianucci et al. (2018)](<doi:10.1007/s13595-018-0730-x>).
#' * The fitted LAD is also compared with six theoretical LAD distributions provided by [de Wit (1965)](https://library.wur.nl/WebQuery/wurpubs/413358).
#' * The distribution type is then classified using a leaf inclination index [Ross (1975)](https://cir.nii.ac.jp/crid/1571980074642440704) and reported as Equation 8 by [Chianucci et al. (2018)](<doi:10.1007/s13595-018-0730-x>).
#'
#' @return A list of two elements:
#' * dataset: a dataframe with three columns indicating the measured LAD (pdf), the G-function (G), for view or inclination angle (theta).
#' * distribution: a vector containing the matched distribution type.

#' @examples
#' fitLAD(0.9,0.9) # uniform LAD distribution
#' fitLAD(2.8,1.18)# planophile LAD distribution
#' fitLAD(1.1,1.7, plot=TRUE)# spherical LAD distribution
#'
#' @export
utils::globalVariables(c('.','theta','pdf','G','name','value'))


fitLAD<-function(mu,nu,plot=FALSE){
  rad=pi/180

  realG<-NULL
  ft=matrix(NA,ncol=89)
  for (i in 1:89){
    t=2*i*rad/pi
    a=(1-t)^(mu-1)
    b=t^(nu-1)
    ft[i]=2/pi*(1/beta(mu,nu))*a*b# probability density function
  }
  frel=ft/sum(ft)

  Gi <- NULL
  for(i in 1:89){
    for(j in 1:89){
      (cot_i <- 1/tan(i*rad))
      (cot_fl <- 1/tan(j*rad))

      if(abs(cot_i*cot_fl)>1) {
        A = cos(i*rad)*cos(j*rad)
      } else {
        A = cos(i*rad)*cos(j*rad)*(1+(2/pi)*((tan(acos(cot_i*cot_fl)))-acos(cot_i*cot_fl)))
      }
      phi=A*frel[i]

      Gi <- c(Gi, phi)
    }
  }

  Gmat <- matrix(Gi, ncol=89)
  Gfun<-apply(Gmat, 1, sum)# G-function
  realG<-rbind(realG,round(Gfun,3))

  out<-data.frame(cbind(pdf=round(as.numeric(frel),4),G=as.numeric(realG)))
  out2<-dplyr::bind_cols(out,deWit)

  distr<-out2  %>%
    dplyr::summarise(dplyr::across(tidyselect::starts_with('fdl.'),~sum(abs(.x-pdf)))) %>%
    dplyr::mutate(distribution=names(.)[which.min(apply(.,MARGIN=2,min))]) %>%
    dplyr::select(distribution) %>%
    dplyr::mutate(distribution=gsub('fdl.','',distribution))

  # out2<-out2 %>%
  #   dplyr::bind_cols(distr) %>%
  #   dplyr::select(theta,pdf,G,distribution)


  out2<-list(dataset=out2 %>%
               dplyr::select(theta,pdf,G),distribution=distr)


  if(isTRUE(plot)){
    legend_colors <- c('erectophile'='blue','planophile'='red','plagiophile'='orange','uniform'='yellow','spherical'='purple','extremophile'='brown','MEASURED'='grey12')
    LADp<-  deWit %>%
      tidyr::pivot_longer(-theta) %>%
      dplyr::mutate(name=gsub('fdl.','',name)) %>%
      ggplot2::ggplot(ggplot2::aes(x=theta,y=value,col=name))+
      ggplot2::geom_line()+
      ggplot2::geom_line(data=out2$dataset,ggplot2::aes(x=theta,y=pdf,color='MEASURED'),lty=2)+
      ggplot2::xlab('Leaf inclination angle')+
      ggplot2::ylab('')+
      ggplot2::theme_minimal()+
      ggplot2::ylim(0,0.05)+
      ggplot2::theme(legend.position="none")+
      ggplot2::ggtitle('Leaf angle distribution')+
      ggplot2::scale_color_manual(values = legend_colors)

    Gp<-Gdf %>%
      tidyr::pivot_longer(-theta) %>%
      dplyr::mutate(name=gsub('fdl.','',name)) %>%
      ggplot2::ggplot(ggplot2::aes(x=theta,y=value,col=name))+
      ggplot2::geom_line()+
      ggplot2::geom_line(data=out2$dataset,ggplot2::aes(x=theta,y=G,color='MEASURED'),lty=2)+
      ggplot2::xlab('View zenith angle')+
      ggplot2::ylab('')+
      ggplot2::labs(col='')+
      ggplot2::theme_minimal()+
      ggplot2::ylim(0.25,1)+
      ggplot2::ggtitle('G-function')+
      ggplot2::scale_color_manual(values = legend_colors)

    print(cowplot::plot_grid(LADp,Gp))
  }

  return(out2)
}
