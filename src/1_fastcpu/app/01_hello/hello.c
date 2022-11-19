void main(void)
{
    int i;
    char* m = (char*) 0x2000;
    for (i = 0; i < 2000; i++)
        m[i] = i;
}
