#include "test_cases.hpp"

#include <iostream>
#include <stdexcept>

int main() {
    const auto tests = cwhip_test::registeredTests();
    std::size_t failures = 0;
    for (const auto& test : tests) {
        try {
            test.second();
            std::cout << "PASS " << test.first << '\n';
        } catch (const std::exception& error) {
            ++failures;
            std::cerr << "FAIL " << test.first << ": " << error.what() << '\n';
        }
    }
    std::cout << tests.size() - failures << "/" << tests.size() << " numeric tests passed\n";
    return failures == 0 ? 0 : 1;
}
