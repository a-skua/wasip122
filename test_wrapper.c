#include <stdio.h>

// Import our random_get function from wrapper
extern int random_get(unsigned char* buf, int len);

int main() {
    unsigned char buffer[16];
    int result = random_get(buffer, 16);
    
    printf("random_get result: %d\n", result);
    printf("Random bytes: ");
    for(int i = 0; i < 16; i++) {
        printf("%02x ", buffer[i]);
    }
    printf("\n");
    
    return 0;
}