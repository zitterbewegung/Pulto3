import asyncio
import aiohttp
import time
from concurrent.futures import ThreadPoolExecutor

class LoadTester:
    def __init__(self, base_url: str = "http://localhost:8000"):
        self.base_url = base_url
    
    async def test_concurrent_requests(self, num_requests: int = 100):
        """Test handling of concurrent requests"""
        start_time = time.time()
        
        async with aiohttp.ClientSession() as session:
            tasks = [
                self.make_request(session, "/health")
                for _ in range(num_requests)
            ]
            results = await asyncio.gather(*tasks)
        
        end_time = time.time()
        
        success_count = sum(1 for r in results if r.status == 200)
        print(f"Completed {success_count}/{num_requests} requests in {end_time - start_time:.2f}s")
        
        return {
            "total_requests": num_requests,
            "successful_requests": success_count,
            "duration": end_time - start_time,
            "requests_per_second": num_requests / (end_time - start_time)
        }
    
    async def make_request(self, session, endpoint):
        async with session.get(f"{self.base_url}{endpoint}") as response:
            return response

if __name__ == "__main__":
    tester = LoadTester()
    result = asyncio.run(tester.test_concurrent_requests(1000))
    print(f"Performance test result: {result}")
