library(rvest)
library(scholar)
library(lubridate)
library(tidyverse)

idtab=read.csv("facultygooglescholarids.csv")
y=year(Sys.Date())
idtab$EndYear[is.na(idtab$EndYear)==T]<-y

scholdat=data.frame()
#get primary data first
for(i in 1:nrow(idtab)){
  dattemp=get_publications(idtab$ID[i])
  dattemp=dattemp[dattemp$year>=idtab$StartYear[i] & !(dattemp$year>idtab$EndYear[i]),]
  dattemp$Faculty=rep(idtab$Name[i],nrow(dattemp))
  scholdat=rbind(scholdat,dattemp)
}


meetingnames="(eeting|bstracts|onference|Joint|abstract|symposium)"

scholdat$Paper=ifelse(grepl(meetingnames, scholdat$journal),"Meeting","Paper")


#get all publications
allPubs <- scholdat |> 
  filter(year > 2009, 
         Paper == "Paper",
         journal != "",
         !is.na(Faculty)) 


length(unique(allPubs$pubid))

#figure out which ones need additional coauthors
needMoreAuthors <- which(str_detect(scholdat$author,pattern = "..."))




output=scholdat[scholdat$year>2009 & scholdat$Paper=="Paper" & scholdat$journal!="",]
output=output[is.na(output$Faculty)==FALSE,]
outputo=output[order(output$year,decreasing=T),]
outputo$author=gsub("...","et al.", outputo$author, fixed=T)
final=with(outputo,data.frame(Faculty=Faculty, Year=year, Publication=paste0(author,". ",year, ". ", title, ", ",journal, " ", number,".")))

write.csv(final,paste0("All faculty pubs to ",y,".csv"),row.names = F)

