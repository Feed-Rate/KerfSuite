Feature: Cut Optimization
  As a workshop operator
  I want to optimize my cut layouts
  So that I minimize material waste

  Scenario: Basic nested optimization
    Given a job with a 4mm kerf
    And a stock sheet of 2440x1220mm with quantity 2
    And 10 pieces of 800x500mm
    When I run the optimization
    Then all 10 pieces should be placed
    And the overall efficiency should be greater than 60%

  Scenario: Respecting grain direction (rotation lock)
    Given a job with a 4mm kerf
    And a stock sheet of 1000x200mm with quantity 1
    And a piece of 90x380mm with rotation locked
    When I run the optimization
    Then the piece should be unplaced
    When I unlock rotation
    And I run the optimization again
    Then the piece should be placed
