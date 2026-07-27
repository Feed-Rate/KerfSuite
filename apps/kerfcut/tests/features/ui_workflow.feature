Feature: UI Workflow
  As a user
  I want a professional and intuitive interface
  So that I can work efficiently

  Scenario: Navigating between tabs
    Given the application is launched
    When I click on the "Stock Sheets" tab
    Then the "Stock Sheets" view should be visible
    When I click on the "Pieces" tab
    Then the "Pieces" view should be visible

  Scenario: Undo/Redo functionality
    Given a new job
    When I add a sheet
    And I perform an Undo operation
    Then the sheet list should be empty
    When I perform a Redo operation
    Then the sheet list should contain 1 sheet
