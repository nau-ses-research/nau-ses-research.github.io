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
  dattemp$Faculty=rep(idtab$Name[i],times = nrow(dattemp))
  scholdat=rbind(scholdat,dattemp)
}


meetingnames="(eeting|bstracts|onference|Joint|abstract|symposium)"

scholdat$Paper=ifelse(grepl(meetingnames, scholdat$journal) | grepl(meetingnames, scholdat$number),"Meeting","Paper")


#get all publications
allPubs <- scholdat |> 
  filter(year >= 2009, 
         Paper == "Paper",
         journal != "",
         !is.na(Faculty)) 

#look for duplicates
allPubsCombined <- allPubs |> 
  mutate(simpleTitle = tolower(str_remove_all(title,"[^A-Za-z]"))) |> 
  group_by(simpleTitle) |> 
  summarise(
    title = title[which.max(str_length(title))],
    author = author[which.max(str_length(author))],
    journal = journal[which.max(str_length(journal))],
    number = number[which.max(str_length(number))],
    year = year[which.max(str_length(year))],
    SES_Faculty = paste(unique(Faculty), collapse = ", "),
    citations = ceiling(mean(cites)),
    pubid = pubid[1],
    facultyForPubid = Faculty[1]) |> 
  arrange(year) |> 
  select(-simpleTitle,everything(),simpleTitle)



#figure out which ones need additional coauthors
#figure out which ones need additional coauthors
getMoreAuthors <- function(author,pubid,facultyForPubid,...){
  if(str_detect(author,pattern = "...")){
    scholId <- idtab$ID[idtab$Name == facultyForPubid]
    fullAuthors <- get_complete_authors(scholId, pubid = pubid)
    return(fullAuthors)
  }else{
    return(author)
  }
}


allAuthors <- pmap_chr(allPubsCombined,insistently(getMoreAuthors,rate_backoff(pause_base = 1, pause_cap = 60*30, max_times = 50)),.progress = TRUE)


#untested code
allPubsCombined$author <- allAuthors

googlesheets4::write_sheet(allPubsCombined,ss = "1HMUJzmD91MlU7zDpWqHmuPwsmjqJIzE5HjaBj3NAMEw",sheet = 1)


ggplot(allPubsCombined) + 
  geom_histogram(aes(x = year),binwidth = 1)


#Department H-index since 2009
H <- 1
npubs <- length(which(allPubsCombined$citations > H))
while(H <= npubs){
  H <- H+1
  npubs <- length(which(allPubsCombined$citations > H))
}
H <- H-1
print(H)



output=scholdat[scholdat$year>2009 & scholdat$Paper=="Paper" & scholdat$journal!="",]
output=output[is.na(output$Faculty)==FALSE,]
outputo=output[order(output$year,decreasing=T),]
outputo$author=gsub("...","et al.", outputo$author, fixed=T)
final=with(outputo,data.frame(Faculty=Faculty, Year=year, Publication=paste0(author,". ",year, ". ", title, ", ",journal, " ", number,".")))

write.csv(final,paste0("All faculty pubs to ",y,".csv"),row.names = F)

