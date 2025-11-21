// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ValidationLib
 * @notice Input validation library for Land Token Protocol
 * @dev Provides validation functions for user inputs and state checks
 */
library ValidationLib {
    /**
     * @dev Custom errors
     */
    error ZeroAddress();
    error ZeroAmount();
    error AmountTooLow(uint256 provided, uint256 required);
    error AmountTooHigh(uint256 provided, uint256 maximum);
    error InvalidPercentage(uint256 percentage);
    error InvalidTimeRange(uint256 start, uint256 end);
    error DeadlinePassed(uint256 deadline, uint256 current);
    error TooEarly(uint256 available, uint256 current);
    error StringTooLong(uint256 length, uint256 maxLength);
    error StringEmpty();
    error InvalidStringFormat();

    /**
     * @notice Validates that an address is not zero
     * @param addr Address to validate
     */
    function validateAddress(address addr) internal pure {
        if (addr == address(0)) revert ZeroAddress();
    }

    /**
     * @notice Validates multiple addresses
     * @param addresses Array of addresses to validate
     */
    function validateAddresses(address[] memory addresses) internal pure {
        for (uint256 i = 0; i < addresses.length; i++) {
            validateAddress(addresses[i]);
        }
    }

    /**
     * @notice Validates that an amount is not zero
     * @param amount Amount to validate
     */
    function validateNonZero(uint256 amount) internal pure {
        if (amount == 0) revert ZeroAmount();
    }

    /**
     * @notice Validates that an amount meets minimum requirement
     * @param amount Amount to validate
     * @param minimum Minimum required amount
     */
    function validateMinAmount(uint256 amount, uint256 minimum) internal pure {
        if (amount < minimum) revert AmountTooLow(amount, minimum);
    }

    /**
     * @notice Validates that an amount does not exceed maximum
     * @param amount Amount to validate
     * @param maximum Maximum allowed amount
     */
    function validateMaxAmount(uint256 amount, uint256 maximum) internal pure {
        if (amount > maximum) revert AmountTooHigh(amount, maximum);
    }

    /**
     * @notice Validates that an amount is within a range
     * @param amount Amount to validate
     * @param minimum Minimum allowed amount
     * @param maximum Maximum allowed amount
     */
    function validateAmountRange(uint256 amount, uint256 minimum, uint256 maximum) internal pure {
        validateMinAmount(amount, minimum);
        validateMaxAmount(amount, maximum);
    }

    /**
     * @notice Validates a percentage value (0-100)
     * @param percentage Percentage to validate
     */
    function validatePercentage(uint256 percentage) internal pure {
        if (percentage > 100) revert InvalidPercentage(percentage);
    }

    /**
     * @notice Validates a basis points value (0-10000)
     * @param basisPoints Basis points to validate (100 bps = 1%)
     */
    function validateBasisPoints(uint256 basisPoints) internal pure {
        if (basisPoints > 10_000) revert InvalidPercentage(basisPoints);
    }

    /**
     * @notice Validates that current time is before a deadline
     * @param deadline Deadline timestamp
     */
    function validateBeforeDeadline(uint256 deadline) internal view {
        if (block.timestamp > deadline) revert DeadlinePassed(deadline, block.timestamp);
    }

    /**
     * @notice Validates that current time is after a start time
     * @param startTime Start timestamp
     */
    function validateAfterStart(uint256 startTime) internal view {
        if (block.timestamp < startTime) revert TooEarly(startTime, block.timestamp);
    }

    /**
     * @notice Validates a time range
     * @param startTime Start timestamp
     * @param endTime End timestamp
     */
    function validateTimeRange(uint256 startTime, uint256 endTime) internal pure {
        if (startTime >= endTime) revert InvalidTimeRange(startTime, endTime);
    }

    /**
     * @notice Validates string is not empty
     * @param str String to validate
     */
    function validateNonEmptyString(string memory str) internal pure {
        if (bytes(str).length == 0) revert StringEmpty();
    }

    /**
     * @notice Validates string length
     * @param str String to validate
     * @param maxLength Maximum allowed length
     */
    function validateStringLength(string memory str, uint256 maxLength) internal pure {
        uint256 length = bytes(str).length;
        if (length == 0) revert StringEmpty();
        if (length > maxLength) revert StringTooLong(length, maxLength);
    }

    /**
     * @notice Validates IPFS hash format (basic check)
     * @param ipfsHash IPFS hash string
     * @dev Checks for Qm prefix and reasonable length (46 chars for CIDv0)
     */
    function validateIPFSHash(string memory ipfsHash) internal pure {
        bytes memory hashBytes = bytes(ipfsHash);

        // Must not be empty
        if (hashBytes.length == 0) revert StringEmpty();

        // CIDv0 should be 46 characters, CIDv1 can vary
        // Accept 40-100 characters as reasonable range
        if (hashBytes.length < 40 || hashBytes.length > 100) {
            revert StringTooLong(hashBytes.length, 100);
        }

        // CIDv0 starts with "Qm", CIDv1 starts with "b" or "z"
        if (
            !(hashBytes[0] == 0x51 && hashBytes[1] == 0x6D) // "Qm"
                && !(hashBytes[0] == 0x62) // "b"
                && !(hashBytes[0] == 0x7A) // "z"
        ) {
            revert InvalidStringFormat();
        }
    }

    /**
     * @notice Validates GPS coordinates
     * @param latitude Latitude in scaled format (1e6)
     * @param longitude Longitude in scaled format (1e6)
     * @dev Valid ranges: lat -90 to +90, lon -180 to +180 (scaled by 1e6)
     */
    function validateCoordinates(int256 latitude, int256 longitude) internal pure {
        // Latitude: -90,000,000 to +90,000,000
        if (latitude < -90_000_000 || latitude > 90_000_000) {
            revert InvalidStringFormat();
        }

        // Longitude: -180,000,000 to +180,000,000
        if (longitude < -180_000_000 || longitude > 180_000_000) {
            revert InvalidStringFormat();
        }

        // Cannot both be zero (no property at 0,0)
        if (latitude == 0 && longitude == 0) {
            revert InvalidStringFormat();
        }
    }

    /**
     * @notice Validates survey number format
     * @param surveyNumber Survey number string
     * @dev Basic validation: non-empty, reasonable length
     */
    function validateSurveyNumber(string memory surveyNumber) internal pure {
        bytes memory numBytes = bytes(surveyNumber);

        // Must not be empty
        if (numBytes.length == 0) revert StringEmpty();

        // Reasonable length (3-50 characters)
        if (numBytes.length < 3 || numBytes.length > 50) {
            revert StringTooLong(numBytes.length, 50);
        }
    }

    /**
     * @notice Validates property area
     * @param areaSqFt Area in square feet
     * @dev Must be between 100 sq ft and 1 million sq ft
     */
    function validateArea(uint256 areaSqFt) internal pure {
        validateAmountRange(areaSqFt, 100, 1_000_000);
    }

    /**
     * @notice Validates property valuation
     * @param valuation Valuation amount
     * @param minValuation Minimum allowed valuation
     * @param maxValuation Maximum allowed valuation
     */
    function validateValuation(uint256 valuation, uint256 minValuation, uint256 maxValuation) internal pure {
        validateNonZero(valuation);
        validateAmountRange(valuation, minValuation, maxValuation);
    }

    /**
     * @notice Validates stake amount against valuation
     * @param stakeAmount Stake amount
     * @param valuation Property valuation
     * @param minStakePercentage Minimum stake as percentage (e.g., 5 for 5%)
     */
    function validateStake(uint256 stakeAmount, uint256 valuation, uint256 minStakePercentage) internal pure {
        validateNonZero(stakeAmount);
        uint256 minStake = (valuation * minStakePercentage) / 100;
        validateMinAmount(stakeAmount, minStake);
    }

    /**
     * @notice Validates token allocation percentages sum to 100%
     * @param percentages Array of percentage values
     */
    function validatePercentageSum(uint256[] memory percentages) internal pure {
        uint256 sum = 0;
        for (uint256 i = 0; i < percentages.length; i++) {
            validatePercentage(percentages[i]);
            sum += percentages[i];
        }
        if (sum != 100) revert InvalidPercentage(sum);
    }

    /**
     * @notice Validates that a value has not changed beyond a threshold
     * @param oldValue Previous value
     * @param newValue New value
     * @param maxChangePercent Maximum allowed change percentage
     */
    function validatePriceChange(uint256 oldValue, uint256 newValue, uint256 maxChangePercent) internal pure {
        if (oldValue == 0) return; // No previous value to compare

        uint256 maxChange = (oldValue * maxChangePercent) / 100;

        // Check both increase and decrease
        if (newValue > oldValue) {
            uint256 increase = newValue - oldValue;
            validateMaxAmount(increase, maxChange);
        } else {
            uint256 decrease = oldValue - newValue;
            validateMaxAmount(decrease, maxChange);
        }
    }
}
