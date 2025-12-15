#include <iostream>
extern "C" void dpi_write(int beats) {
    std::cout << "[C++] Received beats = " << beats << std::endl;
}