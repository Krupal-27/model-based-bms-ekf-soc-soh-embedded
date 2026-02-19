
#!/bin/bash
echo "Compiling BMS test..."

# Go to embedded_c folder
cd ..

# Compile
gcc -o bms_test src/bms_model.c src/safety_fsm.c src/soc_estimator.c src/soh_estimator.c test/test_bms.c -Iinc -lm

# Check if compilation succeeded
if [ $? -eq 0 ]; then
    echo "✅ Compilation successful!"
    echo "Running tests..."
    echo ""
    ./bms_test.exe
else
    echo "❌ Compilation failed!"
fi
