Sys.sleep(6000)

library(rvest)
library(scholar)
library(lubridate)

idtab=read.csv("facultygooglescholarids.csv")
y=year(Sys.Date())
idtab$EndYear[is.na(idtab$EndYear)==T]<-y

scholdat=data.frame()

for(i in 1:nrow(idtab)){
  dattemp=get_publications(idtab$ID[i])
  dattemp=dattemp[dattemp$year>=idtab$StartYear[i] & !(dattemp$year>idtab$EndYear[i]),]
  dattemp$Faculty=rep(idtab$Name[i],nrow(dattemp))
  
  if(nrow(dattemp) == 0){
    next
  }
  
  #get all the coauthors
  if(nrow(dattemp) < 50){
    allAuthors <- try(scholar::get_complete_authors(idtab$ID[i],pubid = dattemp$pubid))
    if(!is(allAuthors,"try-error")){
      dattemp$author <- allAuthors
    }
  }else{
    nr <- nrow(dattemp)
    firstRow <- 1
    nextRow <- 50
    allAuthors <- c()
    while(TRUE){
      newAuthors <- try(scholar::get_complete_authors(idtab$ID[i],pubid = dattemp$pubid[firstRow:nextRow]))
      if(is(newAuthors,"try-error")){
        break
      }
      allAuthors <- c(allAuthors,newAuthors)
      
      if(nextRow >= nr){
        break
      }
      ns <- min(nr - nextRow,50)
      
      nextRow <- nextRow + ns
      firstRow <- firstRow + 50
      Sys.sleep(30)
    }
    
    if(!is(newAuthors,"try-error")){
      dattemp$author <- allAuthors
    }
    
  }
  
  scholdat=rbind(scholdat,dattemp)
  Sys.sleep(60)
}

meetingnames="(eeting|bstracts|onference|Joint|abstract|symposium)"

scholdat$Paper=ifelse(grepl(meetingnames, scholdat$journal),"Meeting","Paper")

output=scholdat[scholdat$year>2009 & scholdat$Paper=="Paper" & scholdat$journal!="",]
output=output[is.na(output$Faculty)==FALSE,]
outputo=output[order(output$year,decreasing=T),]
outputo$author=gsub("...","et al.", outputo$author, fixed=T)
final=with(outputo,data.frame(Faculty=Faculty, Year=year, Publication=paste0(author,". ",year, ". ", title, ", ",journal, " ", number,".")))

write.csv(final,paste0("All faculty pubs to ",y,".csv"),row.names = F)

