Feature: Job Persistence
  As a workshop manager
  I want to save and load my jobs
  So that I can resume work later

  Scenario: Saving and loading a job
    Given a new job named "Production Run A"
    And I add a piece of 500x500mm
    When I save the job to "test_save.kcut"
    And I load the job from "test_save.kcut"
    Then the job name should be "Production Run A"
    And there should be 1 piece in the list

  Scenario: Importing legacy Z-CAD files
    Given a legacy ZAD file with 20 pieces
    When I import the ZAD file
    Then the job should contain 20 pieces
    And the blade kerf should be imported correctly
