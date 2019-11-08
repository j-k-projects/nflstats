#libraries

library(nflscrapR)
library(tidyverse)
library(na.tools)
library(mgcv)
library(teamcolors)

#functions

#scrape
#note plays_filename defined outside this function. need to define it somewhere
#y = season you want
scrape <- function(y) {
  
  report("Loading game data")
  games <- read_csv("http://www.habitatring.com/games.csv")
  games <- games %>%
    filter(season == y & !is.na(result)) %>% 
    mutate(game_id=as.character(game_id))
  
  # load previous data
  report("Loading existing plays data")
  old_warning_level <- getOption("warn")
  options(warn=-1)
  tryCatch(plays <- readRDS(plays_filename) %>% fix_inconsistent_data_types(),error=report)
  options(warn=old_warning_level)
  
  # update plays
  if (exists("plays")) {
    # we have data! identify any missing games
    pulled_games <- plays %>% pull(game_id) %>% unique()
    missing <- games %>% filter(!(game_id %in% pulled_games)) %>% pull(game_id)
    
    # handle missing games
    if (length(missing) > 0)
    {
      # get new plays
      new_plays <- NULL
      for (g in missing)
      {
        tryCatch(plays <- readRDS(plays_filename) %>% fix_inconsistent_data_types(),error=report)
        report(paste0("Scraping plays from game: ",g))
        game_plays <- scrape_json_play_by_play(g)
        game_plays <- game_plays %>%
          fix_inconsistent_data_types()  
        report("Merging existing plays and new plays")
        new_plays <- bind_rows(plays,game_plays) %>% arrange(game_id,play_id)
        saveRDS(new_plays,plays_filename)
        
      }
      
      # finally merge things together
      report("Done hopefully")
      
      rm(new_plays)  # no need for this to take up memory anymore
    }
  }
  
}


#colors
get_colors <- function() {
  colors <- teamcolors %>%
  filter(league == "nfl") %>%
  mutate(
    team_abb = case_when(
      name == "Arizona Cardinals" ~ "ARI",
      name == "Atlanta Falcons" ~ "ATL",
      name == "Baltimore Ravens" ~ "BAL",
      name == "Buffalo Bills" ~ "BUF",
      name == "Carolina Panthers" ~ "CAR",
      name == "Chicago Bears" ~ "CHI",
      name == "Cincinnati Bengals" ~ "CIN",
      name == "Cleveland Browns" ~ "CLE",
      name == "Dallas Cowboys" ~ "DAL",
      name == "Denver Broncos" ~ "DEN",
      name == "Detroit Lions" ~ "DET",
      name == "Green Bay Packers" ~ "GB",
      name == "Houston Texans" ~ "HOU",
      name == "Indianapolis Colts" ~ "IND",
      name == "Jacksonville Jaguars" ~ "JAX",
      name == "Kansas City Chiefs" ~ "KC",
      name == "Los Angeles Rams" ~ "LA",
      name == "Los Angeles Chargers" ~ "LAC",
      name == "Miami Dolphins" ~ "MIA",
      name == "Minnesota Vikings" ~ "MIN",
      name == "New England Patriots" ~ "NE",
      name == "New Orleans Saints" ~ "NO",
      name == "New York Giants" ~ "NYG",
      name == "New York Jets" ~ "NYJ",
      name == "Oakland Raiders" ~ "OAK",
      name == "Philadelphia Eagles" ~ "PHI",
      name == "Pittsburgh Steelers" ~ "PIT",
      name == "Seattle Seahawks" ~ "SEA",
      name == "San Francisco 49ers" ~ "SF",
      name == "Tampa Bay Buccaneers" ~ "TB",
      name == "Tennessee Titans" ~ "TEN",
      name == "Washington Redskins" ~ "WAS",
      TRUE ~ NA_character_
    ),
    posteam = team_abb
  ) %>% select(posteam,primary,secondary)
  
  return(colors)
}

#fix

fix_pbp <- function(pbp) {
  data <- pbp %>%
    filter(!is_na(epa), !is_na(posteam), play_type=="no_play" | play_type=="pass" | play_type=="run") %>%
    mutate(
      pass = if_else(str_detect(desc, "( pass)|(sacked)|(scramble)"), 1, 0),
      rush = if_else(str_detect(desc, "(left end)|(left tackle)|(left guard)|(up the middle)|(right guard)|(right tackle)|(right end)") & pass == 0, 1, 0),
      success = ifelse(epa>0, 1 , 0),
      passer_player_name = ifelse(play_type == "no_play" & pass == 1, 
                                  str_extract(desc, "(?<=\\s)[A-Z][a-z]*\\.\\s?[A-Z][A-z]+(\\s(I{2,3})|(IV))?(?=\\s((pass)|(sack)|(scramble)))"),
                                  passer_player_name),
      receiver_player_name = ifelse(play_type == "no_play" & str_detect(desc, "pass"), 
                                    str_extract(desc, 
                                                "(?<=to\\s)[A-Z][a-z]*\\.\\s?[A-Z][A-z]+(\\s(I{2,3})|(IV))?"),
                                    receiver_player_name),
      rusher_player_name = ifelse(play_type == "no_play" & rush == 1, 
                                  str_extract(desc, "(?<=\\s)[A-Z][a-z]*\\.\\s?[A-Z][A-z]+(\\s(I{2,3})|(IV))?(?=\\s((left end)|(left tackle)|(left guard)|(up the middle)|(right guard)|(right tackle)|(right end)))"),
                                  rusher_player_name),
      name = ifelse(!is_na(passer_player_name), passer_player_name, rusher_player_name),
      name = ifelse(name=="G.Minshew II", "G.Minshew", name),
      yards_gained=ifelse(play_type=="no_play",NA,yards_gained),
      play=1,season=year, incomplete_pass=if_else(interception==1, 1, incomplete_pass)
    ) %>%
    filter(pass==1 | rush==1)
 return(data) 
}



#cpoe
#trains on seasons at least as recent as y
#estimates cpoe on new data pbp using older data old_pbp
get_cpoe <- function(pbp, old_pbp, y) {
  old_data <- readRDS(old_pbp) %>%
    mutate(incomplete_pass=ifelse(interception==1, 1, incomplete_pass)) %>%
    filter((complete_pass==1 | incomplete_pass==1) & air_yards >= -10 & season >= y & !is.na(receiver_player_id) & !is.na(pass_location)) %>%
    select(complete_pass,desc,air_yards,pass_location,name) %>%
    mutate(air_is_zero=ifelse(air_yards==0,1,0))
  gam_y <- gam(complete_pass ~ s(air_yards) + air_is_zero + factor(pass_location), data=old_data, method = "REML")
  
  passes <- pbp%>%filter((complete_pass==1 | incomplete_pass==1) & air_yards >= -10 & !is.na(receiver_player_id) & !is.na(pass_location)) %>%
    select(complete_pass,desc,air_yards,pass_location,name,season) %>%
    mutate(air_is_zero=ifelse(air_yards==0,1,0))
  
  passes$hat <- predict.gam(gam_y,passes)
  passes$r <- passes$complete_pass - passes$hat
  
  cp<-passes %>%group_by(name,season)%>%
    summarize(cpoe=100*mean(r))
  
  return(cp)

}
  
