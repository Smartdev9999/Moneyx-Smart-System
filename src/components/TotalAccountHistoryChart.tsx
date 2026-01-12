import ProfitBarChart from './ProfitBarChart';
import MultiMetricChart from './MultiMetricChart';

interface TotalAccountHistoryChartProps {
  accountIds?: string[];
}

const TotalAccountHistoryChart = ({ accountIds }: TotalAccountHistoryChartProps) => {
  return (
    <div className="space-y-6">
      {/* Profit Analytics Bar Chart */}
      <ProfitBarChart accountIds={accountIds} />
      
      {/* Multi-Metric Performance Chart */}
      <MultiMetricChart accountIds={accountIds} />
    </div>
  );
};

export default TotalAccountHistoryChart;
