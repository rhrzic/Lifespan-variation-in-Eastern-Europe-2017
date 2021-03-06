library(data.table)
library(ggplot2)
library(ggthemes)

setwd(  "C:/Users/jmaburto/Documents/GitHub/Lifespan-variation-in-Eastern-Europe-2017")

load("Data/HMD_Data.RData")


Country.HMD.vec        <- c("BLR","BGR","CZE","HUN","POL","RUS","SVK","UKR","SVN","EST","LVA","LTU")
Country.name.vec       <- c("Belarus","Bulgaria","Czech Republic","Hungary","Poland","Russia",
                            "Slovakia","Ukraine","Slovenia","Estonia","Latvia","Lithuania")
names(Country.name.vec) <- Country.HMD.vec
Sexes        <- c('Female','Male')

Eastern_HMDL             <- HMDL[HMDL$PopName %in% Country.HMD.vec & HMDL$Year >= 1960,]
Eastern_HMDL$Country     <- Country.name.vec[Eastern_HMDL$PopName]
Eastern_HMDL$Sex         <- as.factor(Eastern_HMDL$Sex)
levels(Eastern_HMDL$Sex) <- Sexes

Data_CEE_mx <- Eastern_HMDL[,c(1,2,3,12,14)]
Data_CEE_mx$Sex2 <- Data_CEE_mx$Sex

save(Data_CEE_mx,file = 'mx_CEE.RData')


r1 <- 2
r3 <- 1.1
r2 <- seq(r1,r3,length.out = 10)

Data <- Data_CEE_mx

Data[Data$Age == 0 & Data$Year < 1990]$mx <- Data[Data$Age == 0 & Data$Year < 1990]$mx*r1
for (i in 1:10) {
  Data[Data$Age == 0 & Data$Year == (i+1989)]$mx <- Data[Data$Age == 0 & Data$Year == (i+1989)]$mx*r2[i]
}
Data[Data$Age == 0 & Data$Year >= 2000]$mx <- Data[Data$Age == 0 & Data$Year >= 2000]$mx*r3

makeTransparent<-function(someColor, alpha=100){
  newColor<-col2rgb(someColor)
  apply(newColor, 2, function(curcoldata){rgb(red=curcoldata[1], green=curcoldata[2],
                                              blue=curcoldata[3],alpha=alpha, maxColorValue=255)})
}

AKm02a0 <- function(m0, sex = "m"){
  sex <- rep(sex, length(m0))
  ifelse(sex == "m", 
         ifelse(m0 < .0230, {0.14929 - 1.99545 * m0},
                ifelse(m0 < 0.08307, {0.02832 + 3.26201 * m0},.29915)),
         # f
         ifelse(m0 < 0.01724, {0.14903 - 2.05527 * m0},
                ifelse(m0 < 0.06891, {0.04667 + 3.88089 * m0}, 0.31411))
  )
}

life.expectancy.fromSD <- compiler::cmpfun(function(DT){
      mx <- DT$mx
      sex <- DT$Sex2[1]
      i.openage <- length(mx)
      OPENAGE   <- i.openage - 1
      RADIX     <- 1
      ax        <- mx * 0 + .5
      ax[1]     <- AKm02a0(m0 = mx[1], sex = sex)
      qx        <- mx / (1 + (1 - ax) * mx)
      qx[i.openage]       <- ifelse(is.na(qx[i.openage]), NA, 1)
      ax[i.openage]       <- 1 / mx[i.openage]                   
      px 				    <- 1 - qx
      px[is.nan(px)]      <- 0
      lx 			        <- c(RADIX, RADIX * cumprod(px[1:OPENAGE]))
      dx 				    <- lx * qx
      Lx 				    <- lx - (1 - ax) * dx
      Lx[i.openage ]	    <- lx[i.openage ] * ax[i.openage ]
      Tx 				    <- c(rev(cumsum(rev(Lx[1:OPENAGE]))),0) + Lx[i.openage]
      ex 				    <- Tx / lx
      ex[1]
})

edag.function.fromSD <- compiler::cmpfun(function(DT){
  mx <- DT$mx
  sex <- DT$Sex2[1]
  i.openage <- length(mx)
  OPENAGE   <- i.openage - 1
  RADIX     <- 1
  ax        <- mx * 0 + .5
  ax[1]     <- AKm02a0(m0 = mx[1], sex = sex)
  qx        <- mx / (1 + (1 - ax) * mx)
  qx[i.openage]       <- ifelse(is.na(qx[i.openage]), NA, 1)
  ax[i.openage]       <- 1 / mx[i.openage]                   
  px 				    <- 1 - qx
  px[is.nan(px)]      <- 0
  lx 			        <- c(RADIX, RADIX * cumprod(px[1:OPENAGE]))
  dx 				    <- lx * qx
  Lx 				    <- lx - (1 - ax) * dx
  Lx[i.openage ]	    <- lx[i.openage ] * ax[i.openage ]
  Tx 				    <- c(rev(cumsum(rev(Lx[1:OPENAGE]))),0) + Lx[i.openage]
  ex 				    <- Tx / lx
  l <- length(ex)
  ed <- (sum(dx[-l]* (ex[-l] + ax[-l]*(ex[-1]-ex[-l]) )) + ex[l])
  ed
})

DT1 <- Data[,list(ex = life.expectancy.fromSD(.SD), ed = edag.function.fromSD(.SD)), by = list(Year,Sex,Country)]
DT2 <- DT1[,list(year=Year[-1L],dif.ex = diff(ex),dif.ed = diff(ed)), by = list(Sex,Country)] 

DT2$Category2 <-  4
DT2[DT2$dif.ed >= 0 & DT2$dif.ex >= 0, ]$Category2  <-3
DT2[DT2$dif.ed < 0 & DT2$dif.ex < 0, ]$Category2 <- 1
DT2[DT2$dif.ed >= 0 & DT2$dif.ex < 0, ]$Category2 <- 2


DT2$Category <- 2  
DT2[DT2$dif.ed >= 0 & DT2$dif.ex >= 0, ]$Category <- 1
DT2[DT2$dif.ed < 0 & DT2$dif.ex < 0, ]$Category <-   1
DT2[DT2$Country=='Russia', ]$Category <- 3
DT2$Category   <- factor(DT2$Category,levels=c(1:3),labels=c('Negative','Positive','Russia'))


DT2$Period     <- (cut(DT2$year+1, breaks=c(1960,1981,1989,1995,2000,Inf),labels= c("Stagnation 1960-1980","Improvements 1980-1988","Deterioration 1988-1994",
                                                                                    "Divergence 1994-2000","Convergence 2000-present")))
### Plots of first differences versus first differences
abs.dif.male <- ggplot(DT2[DT2$Sex == 'Male',], aes(dif.ed, dif.ex,colour=Category,group=Period)) +
  ggtitle( expression(paste('Association between changes in ',e[0],' and ',e[0]^"\u2020",', males.')) , subtitle = 'Absolute changes (years)')+
  geom_vline(aes(xintercept=0),show.legend = F,linetype=2,size=.6, colour="gray48")+
  geom_hline(aes(yintercept=0),show.legend = F,linetype=2,size=.6, colour="gray48")+
  geom_point(show.legend = F,size =2.5)+
  scale_colour_manual('Country', values = c(makeTransparent("#e7657d",150),makeTransparent('gray71',100), "deepskyblue4"))+
  facet_wrap(~Period,nrow = 1)+
  #theme_minimal(base_size = 18)+
  theme_fivethirtyeight(base_size = 18)+
  theme(panel.border = element_rect(fill=NA,color="black", size=0.5, 
                                    linetype="solid"),
        axis.title = element_text(),
        rect = element_rect(fill = 'white', 
                            linetype = 0, colour = NA))+
  scale_y_continuous( expression(paste('Changes in ',e[0])),limits = c(-3.2,3.2)) +
  scale_x_continuous( expression(paste('Changes in ',e[0]^"\u2020")),limits = c(-3.2,3.2))

abs.dif.male

require(gridExtra)
pdf(file="Outcomes/For the review/Changes_IMR.pdf",width=15,height=5,pointsize=6,useDingbats = F)
grid.arrange(abs.dif.male,nrow = 1)
dev.off()



### get proportions
males <- DT2[DT2$Sex=='Male']


T1 <- t(table(males$Category2,males$Period))/colSums(table(males$Category2,males$Period))
T2 <- T1[,1]+T1[,3]
T3 <- T1[,2]+T1[,4]

T4 <- round(rbind(T2,T3)*100,2)
row.names(T4) <- rev(c('same direction (%)', 'opposite direction (%)'))


datatable(T4, options = list(paging=FALSE,ordering=T,searching=F),rownames = T)


