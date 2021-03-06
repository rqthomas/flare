library(tidyverse)
set.seed(1)

forecast_location <- "/Users/quinn/Dropbox/Research/SSC_forecasting/flare_users_guide_v2/forecast_location"
working_directory <- "/Users/quinn/Dropbox/Research/SSC_forecasting/flare_users_guide_v2/working_directory"


file.copy(system.file("data", "configure_flare.yml", package="FLAREr"), forecast_location)
file.copy(system.file("data", "run_configuration.yml", package="FLAREr"), forecast_location)

file.copy(system.file("data", "parameter_calibration_config.csv", package="FLAREr"), forecast_location)
file.copy(system.file("data", "states_config.csv", package="FLAREr"), forecast_location)
file.copy(system.file("data", "states_process_error.csv", package="FLAREr"), forecast_location)
file.copy(system.file("data", "observations_config.csv", package="FLAREr"), forecast_location)

file.copy(system.file("data", "glm3.nml", package="FLAREr"), forecast_location)

file.copy(from = system.file("data/input_data", package= "FLAREr"), to = forecast_location, recursive = TRUE)

config <- yaml::read_yaml(file.path(forecast_location,"configure_flare.yml"))
run_config <- yaml::read_yaml(file.path(forecast_location,"run_configuration.yml"))


config$run_config <- run_config
config$run_config$forecast_location <- file.path(forecast_location)
config$run_config$execute_location <- file.path(forecast_location, "working_directory")

config$data_location <- file.path(forecast_location, "input_data")
config$qaqc_data_location <- file.path(forecast_location, "input_data")

if(!dir.exists(config$run_config$execute_location)){
  dir.create(config$run_config$execute_location)
}

pars_config <- readr::read_csv(file.path(config$run_config$forecast_location, config$par_file), col_types = readr::cols())
obs_config <- readr::read_csv(file.path(config$run_config$forecast_location, config$obs_config_file), col_types = readr::cols())
states_config <- readr::read_csv(file.path(config$run_config$forecast_location,config$states_config_file), col_types = readr::cols())

cleaned_observations_file_long <- file.path(config$qaqc_data_location,"observations_postQAQC_long.csv")
cleaned_inflow_file <- file.path(config$qaqc_data_location, "/inflow_postQAQC.csv")
observed_met_file <- file.path(config$qaqc_data_location,"observed-met_fcre.nc")

met_out <- FLAREr::generate_glm_met_files(obs_met_file = observed_met_file,
                                          out_dir = config$run_config$execute_location,
                                          forecast_dir = file.path(config$data_location, config$forecast_met_model),
                                          config = config)

inflow_outflow_files <- FLAREr::create_glm_inflow_outflow_files(inflow_file_dir = file.path(config$data_location, config$forecast_inflow_model),
                                                                inflow_obs = cleaned_inflow_file,
                                                                working_directory = config$run_config$execute_location,
                                                                config = config,
                                                                state_names = NULL)

obs <- FLAREr::create_obs_matrix(cleaned_observations_file_long,
                                 obs_config,
                                 config)

states_config <- FLAREr::generate_states_to_obs_mapping(states_config, obs_config)

model_sd <- FLAREr::initiate_model_error(config, states_config, config_file_location = config$run_config$forecast_location)

init <- FLAREr::generate_initial_conditions(states_config,
                                            obs_config,
                                            pars_config,
                                            obs,
                                            config,
                                            restart_file = config$run_config$restart_file,
                                            historical_met_error = met_out$historical_met_error)

enkf_output <- FLAREr::run_da_forecast(states_init = init$states,
                                       pars_init = init$pars,
                                       aux_states_init = init$aux_states_init,
                                       obs = obs,
                                       obs_sd = obs_config$obs_sd,
                                       model_sd = model_sd,
                                       working_directory = config$run_config$execute_location,
                                       met_file_names = met_out$filenames,
                                       inflow_file_names = inflow_outflow_files$inflow_file_name,
                                       outflow_file_names = inflow_outflow_files$outflow_file_name,
                                       config = config,
                                       pars_config = pars_config,
                                       states_config = states_config,
                                       obs_config = obs_config,
                                       da_method = config$da_method,
                                       par_fit_method = config$par_fit_method)


saved_file <- FLAREr::write_forecast_netcdf(enkf_output,
                                            forecast_location = config$run_config$forecast_location)

FLAREr::create_flare_metadata(file_name = saved_file,
                         enkf_output)

FLAREr::plotting_general(file_name = saved_file,
                         qaqc_location = config$qaqc_data_location)

