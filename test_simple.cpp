#include <iostream>
#include <vector>

int main() {
    std::cout << "Starting simple test program..." << std::endl;
    
    // Simple loop to consume some CPU cycles
    int sum = 0;
    for (int i = 0; i < 1000000; i++) {
        sum += i;
    }
    
    // Some memory operations
    std::vector<int> data(1000);
    for (int i = 0; i < 1000; i++) {
        data[i] = i * 2;
    }
    
    std::cout << "Sum: " << sum << std::endl;
    std::cout << "Vector size: " << data.size() << std::endl;
    std::cout << "Test completed successfully!" << std::endl;
    
    return 0;
}
